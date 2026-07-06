import {
  isConnected,
  isAllowed,
  requestAccess,
  signTransaction as freighterSign,
} from "@stellar/freighter-api";

export async function isFreighterInstalled(): Promise<boolean> {
  const result = await isConnected();
  return result.isConnected;
}

// Checks whether the user has granted this site access in Freighter.
// Returns false if the extension is absent or the site permission was revoked.
export async function isFreighterAuthorized(): Promise<boolean> {
  const installed = await isFreighterInstalled();
  if (!installed) return false;
  const result = await isAllowed();
  return result.isAllowed;
}

export async function connectFreighter(): Promise<string> {
  const result = await requestAccess();
  if (result.error) throw new Error(result.error.message);
  return result.address;
}

export async function signTransaction(
  xdr: string,
  networkPassphrase: string
): Promise<string> {
  const result = await freighterSign(xdr, { networkPassphrase });
  if (result.error) throw new Error(result.error.message);
  if (!result.signedTxXdr) throw new Error("Signing cancelled");
  return result.signedTxXdr;
}
