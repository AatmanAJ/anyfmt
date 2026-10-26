// Friendly names for the generated OpenAPI types. Everything here comes from
// src/generated/openapi.ts (`npm run generate`); nothing is written by hand.

import type { components } from './generated/openapi.js';

type S = components['schemas'];

export type ApiKeyScope = S['ApiKeyScope'];
export type StoredFile = S['StoredFile'];
export type Upload = S['Upload'];
export type ConversionStatus = S['ConversionStatus'];
export type ConversionInput = S['ConversionInput'];
export type ConversionCreate = S['ConversionCreate'];
export type Conversion = S['Conversion'];
export type ConversionPage = S['ConversionPage'];
export type ConversionUsage = S['ConversionUsage'];
export type OptionValue = S['OptionValue'];
export type FormatList = S['FormatList'];
export type FormatInfo = S['FormatInfo'];
export type FormatTarget = S['FormatTarget'];
export type AnyfmtSchema = S['AnyfmtSchema'];
export type OptionSchema = S['OptionSchema'];
export type OptionSpec = S['OptionSpec'];
export type WebhookCreate = S['WebhookCreate'];
export type WebhookEndpoint = S['WebhookEndpoint'];
export type WebhookEndpointCreated = S['WebhookEndpointCreated'];
export type WebhookEvent = S['WebhookEvent'];
export type WebhookEventType = S['WebhookEventType'];
export type Usage = S['Usage'];
export type ErrorBody = S['Error'];
export type ErrorCode = S['Error']['error']['code'];

export type { components, paths, operations, webhooks } from './generated/openapi.js';
