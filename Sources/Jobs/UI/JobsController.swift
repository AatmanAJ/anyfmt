import AppKit
import HaloCore

/// The one object the app wires up for jobs: queue + progress windows + recents.
///
/// The wheel calls `convert(…)` / `runTool(…)` on drop with the drop point;
/// the menu bar reads `recents.items`. Settings feed `policyProvider` and
/// may change `queue.limits`.
@MainActor
final class JobsController {
    let queue: JobQueue
    let presenter: ProgressPresenter
    let recents: RecentConversions
    /// Extra hook for the app (notifications, sounds) after recents are updated.
    var onJobFinished: ((JobRecord) -> Void)?

    init(policyProvider: @escaping @MainActor () -> OutputPolicy = { .default },
         limits: ConcurrencyLimits = .system, recents: RecentConversions = .shared, reveal: Reveal = .finder,
         scratch: JobScratch = .default) {
        scratch.purgeStale()
        queue = JobQueue(limits: limits, scratch: scratch, policyProvider: policyProvider)
        presenter = ProgressPresenter(queue: queue, reveal: reveal)
        self.recents = recents
        queue.onJobFinished = { [weak self] record in
            guard let self else { return }
            self.recents.add(record)
            self.onJobFinished?(record)
        }
    }

    /// Converts the dropped files to the segment's target. Returns the batch id.
    @discardableResult
    func convert(_ files: [URL], to target: RouteTarget, options: OptionValues = OptionValues(), near point: CGPoint) -> UUID {
        let plan = BatchConversion(files: files, target: target, options: options)
        let id = queue.submit(plan)
        presenter.present(batch: id, near: point)
        return id
    }

    /// Runs a tool (instant or from an editor's "Save copy"). Returns the batch id.
    @discardableResult
    func runTool(_ tool: ToolID, on files: [URL], options: OptionValues? = nil, near point: CGPoint) -> UUID {
        let jobs = ToolJob.batch(tool: tool, inputs: files, options: options)
        let first = jobs.first
        let id = queue.submitBatch(jobs, title: first?.title ?? tool.rawValue,
                                   activityTitle: first?.activityTitle, completedTitle: first?.completedTitle,
                                   failedTitle: first?.failedTitle, fileCount: files.count)
        presenter.present(batch: id, near: point)
        return id
    }

    /// Any other job (cloud jobs): queued and shown.
    @discardableResult
    func submit(_ job: any Job, near point: CGPoint) -> UUID {
        let id = queue.submit(job)
        presenter.present(job: id, near: point)
        return id
    }
}
