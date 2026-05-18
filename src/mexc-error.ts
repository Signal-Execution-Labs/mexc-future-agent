export class MexcError extends Error {
  readonly code?: number;
  readonly status?: number;
  readonly bodySnippet?: string;

  constructor(
    message: string,
    opts: { code?: number; status?: number; bodySnippet?: string } = {}
  ) {
    super(message);
    this.name = "MexcError";
    this.code = opts.code;
    this.status = opts.status;
    this.bodySnippet = opts.bodySnippet;
  }
}
