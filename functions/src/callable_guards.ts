import {HttpsError} from "firebase-functions/https";

export type CallableFlowContext = {
  auth?: {
    uid?: string | null;
  };
};

export function requireCallableAuth(
  context: CallableFlowContext | undefined,
): string {
  const uid = context?.auth?.uid;
  if (!uid) {
    throw new HttpsError(
      "unauthenticated",
      "Sign in to use Kolo AI features.",
    );
  }
  return uid;
}
