import Combine
import Foundation

/// Runs jobs with per-resource concurrency limits and publishes their state.
///
/// - Concurrency: CPU ≤ performance cores − 1, VideoToolbox ≤ 1, IO ≤ 4,
///   network ≤ 2 (`ConcurrencyLimits`). FIFO within each class; classes don't
///   block each other, so a hardware encode never waits behind 40 HEICs.
/// - Each job runs detached in its own scratch folder (`JobRunner`), removed
///   afterwards whatever happens. Cancelling cancels the job's Task, which
///   terminates any child process (`ProcessRunner`).
/// - Progress is polled from `Job.progress` at most every `pollInterval`
///   (30 Hz by default) and only while something runs, so an idle queue costs
///   nothing. Records are republished only when a value visibly changes.
@MainActor
public final class JobQueue: ObservableObject {
    @Published public private(set) var records: [JobRecord] = []
    @Published public private(set) var batches: [JobBatch] = []

    public var limits: ConcurrencyLimits { didSet { pump() } }
    /// Current output settings; snapshotted when a job is submitted or retried.
    public var policyProvider: @MainActor () -> OutputPolicy
    /// Called once per finished run (succeeded, failed or cancelled): reveal,
    /// notifications, recents.
    public var onJobFinished: (@MainActor (JobRecord) -> Void)?
    /// Called when every job of a batch has finished.
    public var onBatchFinished: (@MainActor (JobBatch, BatchProgress) -> Void)?
    /// Finished records kept for the UI; older ones are dropped.
    public var maxFinishedRecords = 200

    public let scratch: JobScratch
    public let pollInterval: TimeInterval

    private struct Running {
        let task: Task<[URL], Error>
        let resource: ResourceClass
        let attempt: Int
        var eta = ETAModel()
    }

    private let engineContext: EngineContext
    private let clock: @Sendable () -> TimeInterval
    private var jobs: [UUID: any Job] = [:]
    private var index: [UUID: Int] = [:]
    private var pending: [ResourceClass: [UUID]] = [:]
    private var running: [UUID: Running] = [:]
    private var batchETAs: [UUID: ETAModel] = [:]
    private var poller: Task<Void, Never>?
    private var idleWaiters: [CheckedContinuation<Void, Never>] = []
    private var jobWaiters: [UUID: [CheckedContinuation<JobRecord?, Never>]] = [:]

    public init(limits: ConcurrencyLimits = .system, scratch: JobScratch = .default,
                engineContext: EngineContext = EngineContext(), pollInterval: TimeInterval = 1.0 / 30,
                policyProvider: @escaping @MainActor () -> OutputPolicy = { .default },
                clock: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.limits = limits
        self.scratch = scratch
        self.engineContext = engineContext
        self.pollInterval = max(1.0 / 30, pollInterval)
        self.policyProvider = policyProvider
        self.clock = clock
    }

    // MARK: Submitting

    /// Queues one job. Submitting a job that's already queued or running is a no-op.
    @discardableResult
    public func submit(_ job: any Job) -> UUID {
        enqueue(job, batch: nil)
        pump()
        return job.id
    }

    /// Queues several jobs shown as one card ("3 of 12").
    @discardableResult
    public func submitBatch(_ jobs: [any Job], title: String, activityTitle: String? = nil, completedTitle: String? = nil,
                            failedTitle: String? = nil, note: String? = nil, fileCount: Int? = nil) -> UUID {
        let batch = JobBatch(title: title, activityTitle: activityTitle, completedTitle: completedTitle,
                             failedTitle: failedTitle, note: note, jobIDs: jobs.map(\.id), fileCount: fileCount)
        batches.append(batch)
        for job in jobs { enqueue(job, batch: batch.id) }
        pump()
        if jobs.isEmpty { onBatchFinished?(batch, BatchProgress([])) }
        return batch.id
    }

    /// Queues a planned multi-file conversion. Returns the batch id.
    @discardableResult
    public func submit(_ conversion: BatchConversion) -> UUID {
        submitBatch(conversion.jobs, title: conversion.title, activityTitle: conversion.activityTitle,
                    completedTitle: conversion.completedTitle, failedTitle: conversion.failedTitle,
                    note: conversion.skippedNote, fileCount: conversion.fileCount)
    }

    private func enqueue(_ job: any Job, batch: UUID?) {
        if let existing = record(job.id), !existing.isFinished { return }
        if index[job.id] != nil { remove(ids: [job.id]) }
        let described = job as? JobDescribing
        let rec = JobRecord(id: job.id, title: job.title, activityTitle: described?.activityTitle,
                            completedTitle: described?.completedTitle, failedTitle: described?.failedTitle,
                            inputs: job.inputs, resourceClass: job.resourceClass, batchID: batch,
                            policy: policyProvider())
        jobs[job.id] = job
        index[job.id] = records.count
        records.append(rec)
        pending[job.resourceClass, default: []].append(job.id)
    }

    // MARK: Controlling

    /// Cancels a job, or every unfinished job of a batch. Queued jobs are
    /// cancelled at once; running ones stop cooperatively (child processes are
    /// terminated) and their record flips to `.cancelled` when they've exited.
    public func cancel(_ id: UUID) {
        if let batch = batch(id) {
            // Queued first, so freed slots don't start more of this batch.
            for jid in batch.jobIDs where record(jid)?.isQueued == true { cancelJob(jid) }
            for jid in batch.jobIDs { cancelJob(jid) }
            return
        }
        cancelJob(id)
    }

    public func cancelAll() {
        for rec in records where rec.isQueued { cancelJob(rec.id) }
        for id in Array(running.keys) { cancelJob(id) }
    }

    private func cancelJob(_ id: UUID) {
        guard let rec = record(id), !rec.isFinished else { return }
        if rec.isQueued {
            pending[rec.resourceClass]?.removeAll { $0 == id }
            update(id) {
                $0.state = .cancelled
                $0.cancelRequested = true
                $0.finishedAt = Date()
            }
            finished(id)
        } else if let run = running[id], !rec.cancelRequested {
            update(id) { $0.cancelRequested = true }
            run.task.cancel()
        }
    }

    /// Runs a failed or cancelled job again (or every failed/cancelled job of a
    /// batch) with a fresh policy snapshot. Succeeded jobs are never re-run.
    @discardableResult
    public func retry(_ id: UUID) -> Bool {
        if let batch = batch(id) {
            let any = batch.jobIDs.map { retryJob($0) }.contains(true)
            pump()
            return any
        }
        let ok = retryJob(id)
        pump()
        return ok
    }

    private func retryJob(_ id: UUID) -> Bool {
        guard let rec = record(id), jobs[id] != nil else { return false }
        switch rec.state {
        case .failed, .cancelled: break
        default: return false
        }
        let policy = policyProvider()
        update(id) {
            $0.state = .queued
            $0.policy = policy
            $0.fraction = 0
            $0.eta = nil
            $0.outputs = []
            $0.errorMessage = nil
            $0.errorDetails = nil
            $0.startedAt = nil
            $0.finishedAt = nil
            $0.cancelRequested = false
            $0.attempt += 1
        }
        pending[rec.resourceClass, default: []].append(id)
        return true
    }

    /// Drops finished records (and batches with nothing left running).
    public func clearFinished() {
        let done = records.filter(\.isFinished).map(\.id)
        let activeBatches = Set(records.filter { !$0.isFinished }.compactMap(\.batchID))
        remove(ids: done)
        batches.removeAll { !activeBatches.contains($0.id) }
    }

    // MARK: Reading

    public func record(_ id: UUID) -> JobRecord? {
        guard let i = index[id], i < records.count else { return nil }
        return records[i]
    }

    public func batch(_ id: UUID) -> JobBatch? { batches.first { $0.id == id } }

    public func records(inBatch id: UUID) -> [JobRecord] {
        guard let batch = batch(id) else { return [] }
        return batch.jobIDs.compactMap(record)
    }

    public func runningCount(for resource: ResourceClass) -> Int {
        running.values.filter { $0.resource == resource }.count
    }

    public var queuedCount: Int { pending.values.reduce(0) { $0 + $1.count } }
    public var runningCount: Int { running.count }
    public var isIdle: Bool { running.isEmpty && queuedCount == 0 }

    /// Resumes when nothing is queued or running (CLI, tests).
    public func waitUntilIdle() async {
        if isIdle { return }
        await withCheckedContinuation { idleWaiters.append($0) }
    }

    /// Resumes when `id` has finished; returns its record.
    public func waitForJob(_ id: UUID) async -> JobRecord? {
        guard let rec = record(id) else { return nil }
        if rec.isFinished { return rec }
        return await withCheckedContinuation { jobWaiters[id, default: []].append($0) }
    }

    // MARK: Scheduling

    private func pump() {
        for resource in [ResourceClass.videoToolbox, .cpu, .io, .network] {
            let limit = limits.limit(for: resource)
            while runningCount(for: resource) < limit, var queue = pending[resource], !queue.isEmpty {
                let id = queue.removeFirst()
                pending[resource] = queue
                start(id)
            }
        }
    }

    private func start(_ id: UUID) {
        guard let job = jobs[id], let rec = record(id), rec.isQueued else { return }
        let policy = rec.policy
        let scratch = self.scratch
        let engine = self.engineContext
        let attempt = rec.attempt
        let task = Task.detached(priority: .userInitiated) {
            try await JobRunner.run(job, policy: policy, engine: engine, scratch: scratch)
        }
        running[id] = Running(task: task, resource: job.resourceClass, attempt: attempt)
        update(id) {
            $0.state = .running
            $0.startedAt = Date()
        }
        Log.jobs.debug("start \(id, privacy: .public) [\(job.resourceClass.rawValue, privacy: .public)]")
        Task { [weak self] in
            let result = await task.result
            self?.complete(id, attempt: attempt, result)
        }
        ensurePolling()
    }

    private func complete(_ id: UUID, attempt: Int, _ result: Result<[URL], Error>) {
        guard let run = running[id], run.attempt == attempt else { return }
        running[id] = nil
        let job = jobs[id]
        update(id) { rec in
            rec.finishedAt = Date()
            rec.eta = nil
            switch result {
            case .success(let urls):
                rec.state = .succeeded(urls)
                rec.outputs = urls
                rec.fraction = 1
            case .failure(let error):
                let failure = JobFailure.from(error)
                if failure.isCancellation || rec.cancelRequested {
                    rec.state = .cancelled
                } else {
                    let details = JobDiagnostics.report(title: rec.title, diagnostics: (job as? JobDescribing)?.diagnostics ?? "",
                                                        failure: failure, attempt: rec.attempt)
                    rec.state = .failed(message: failure.message, details: details)
                    rec.errorMessage = failure.message
                    rec.errorDetails = details
                    Log.jobs.error("job failed: \(failure.details, privacy: .public)")
                }
            }
        }
        finished(id)
        pump()
    }

    /// Bookkeeping after any job reaches a final state.
    private func finished(_ id: UUID) {
        guard let rec = record(id) else { return }
        onJobFinished?(rec)
        if let bid = rec.batchID, batch(bid) != nil {
            let progress = BatchProgress(records(inBatch: bid))
            updateBatch(bid) {
                $0.fraction = progress.fraction
                if progress.isFinished { $0.eta = nil }
            }
            if progress.isFinished, let b = batch(bid) {
                batchETAs[bid] = nil
                onBatchFinished?(b, progress)
            }
        }
        jobWaiters.removeValue(forKey: id)?.forEach { $0.resume(returning: rec) }
        pruneFinished()
        if isIdle {
            let waiters = idleWaiters
            idleWaiters = []
            waiters.forEach { $0.resume() }
        }
    }

    private func pruneFinished() {
        let finishedIDs = records.filter(\.isFinished).map(\.id)
        guard finishedIDs.count > maxFinishedRecords else { return }
        let activeBatches = Set(records.filter { !$0.isFinished }.compactMap(\.batchID))
        // Keep whole active batches; drop the oldest standalone/finished-batch records.
        let droppable = records.filter { $0.isFinished && !($0.batchID.map(activeBatches.contains) ?? false) }.map(\.id)
        let drop = Array(droppable.prefix(finishedIDs.count - maxFinishedRecords))
        remove(ids: drop)
        let referenced = Set(records.compactMap(\.batchID))
        batches.removeAll { !referenced.contains($0.id) && !$0.jobIDs.isEmpty }
    }

    private func remove(ids: [UUID]) {
        guard !ids.isEmpty else { return }
        let drop = Set(ids)
        records.removeAll { drop.contains($0.id) }
        for id in drop { jobs[id] = nil }
        index = Dictionary(uniqueKeysWithValues: records.enumerated().map { ($1.id, $0) })
    }

    // MARK: Progress polling

    private func ensurePolling() {
        guard poller == nil else { return }
        let nanos = UInt64(pollInterval * 1_000_000_000)
        poller = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: nanos)
                guard let self, self.tick() else { return }
            }
        }
    }

    /// One poll. Returns false (and stops polling) when nothing is running.
    private func tick() -> Bool {
        guard !running.isEmpty else {
            poller = nil
            return false
        }
        let now = clock()
        var recs = records
        var changed = false
        var touchedBatches = Set<UUID>()
        for id in Array(running.keys) {
            guard var run = running[id], let i = index[id], i < recs.count, let job = jobs[id] else { continue }
            let raw = job.progress.fractionCompleted
            let f = raw.isFinite ? min(1, max(0, raw)) : 0
            let eta = run.eta.update(fraction: f, at: now)
            running[id] = run
            if abs(recs[i].fraction - f) >= 0.001 || Self.etaMoved(recs[i].eta, eta) {
                recs[i].fraction = f
                recs[i].eta = eta
                changed = true
                if let b = recs[i].batchID { touchedBatches.insert(b) }
            }
        }
        if changed { records = recs }
        if !touchedBatches.isEmpty {
            var bs = batches
            for (i, b) in bs.enumerated() where touchedBatches.contains(b.id) {
                let progress = BatchProgress(b.jobIDs.compactMap(record))
                var model = batchETAs[b.id] ?? ETAModel()
                let eta = model.update(fraction: progress.fraction, at: now)
                batchETAs[b.id] = model
                bs[i].fraction = progress.fraction
                bs[i].eta = eta
            }
            batches = bs
        }
        return true
    }

    private static func etaMoved(_ a: TimeInterval?, _ b: TimeInterval?) -> Bool {
        switch (a, b) {
        case (nil, nil): false
        case let (x?, y?): abs(x - y) >= 0.5
        default: true
        }
    }

    // MARK: Helpers

    /// Mutates one record and publishes once.
    private func update(_ id: UUID, _ body: (inout JobRecord) -> Void) {
        guard let i = index[id], i < records.count else { return }
        var rec = records[i]
        body(&rec)
        records[i] = rec
    }

    private func updateBatch(_ id: UUID, _ body: (inout JobBatch) -> Void) {
        guard let i = batches.firstIndex(where: { $0.id == id }) else { return }
        var b = batches[i]
        body(&b)
        batches[i] = b
    }
}
