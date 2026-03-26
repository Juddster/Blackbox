import { PullResponse, PushResponse, ValidationErrorPayload } from "../domain/types.js";

export interface HttpSuccess<TBody> {
  statusCode: number;
  body: TBody;
}

export type PushHttpResult = HttpSuccess<PushResponse> | HttpSuccess<ValidationErrorPayload>;
export type PullHttpResult = HttpSuccess<PullResponse> | HttpSuccess<ValidationErrorPayload>;
