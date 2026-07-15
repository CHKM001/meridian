import type { VercelRequest, VercelResponse } from "@vercel/node";
import { handleGetPositions } from "@meridian/api-core";
import { applyCors, checkRateLimit } from "../../_lib/middleware.js";

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (applyCors(req, res)) return;
  if (!(await checkRateLimit(req, res))) return;
  const { publicKey } = req.query as { publicKey: string };

  const result = await handleGetPositions(publicKey);
  if (result.error) {
    console.error("[positions] error:", result.error);
  }
  res.status(result.status).json(result.body);
}
