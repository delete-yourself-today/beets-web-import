export type Message =
  | { type: "resize"; cols: number; rows: number }
  | { type: "input"; data: string }
  | { type: "upload"; jobId: string };
