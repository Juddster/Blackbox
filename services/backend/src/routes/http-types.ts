import { PullResponse, PushResponse, ValidationErrorPayload } from "../domain/types";

export interface HttpSuccess<TBody> {
  statusCode: number;
  body: TBody;
}

export type PushHttpResult = HttpSuccess<PushResponse> | HttpSuccess<ValidationErrorPayload>;
export type PullHttpResult = HttpSuccess<PullResponse> | HttpSuccess<ValidationErrorPayload>;
