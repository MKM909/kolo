import assert from "node:assert/strict";
import test from "node:test";
import {HttpsError} from "firebase-functions/https";
import {requireCallableAuth} from "./callable_guards.js";

test("requireCallableAuth returns the caller uid", () => {
  assert.equal(requireCallableAuth({auth: {uid: "user-123"}}), "user-123");
});

test("requireCallableAuth rejects unauthenticated callers", () => {
  assert.throws(
    () => requireCallableAuth({}),
    (error) =>
      error instanceof HttpsError &&
      error.code === "unauthenticated" &&
      error.message.includes("Sign in"),
  );
});
