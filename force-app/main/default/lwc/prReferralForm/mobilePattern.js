/**
 * 002 Partner referral (S02, D5): the client-side check for the Mobile field, used as the lightning-input `pattern`.
 * The browser anchors it to the whole value and compiles it with the `v` flag, so a literal hyphen in a character
 * class must be escaped (`[ \-]`, not `[ -]`); an invalid pattern would be ignored and every value accepted.
 *
 * It accepts what PR_ReferralService accepts: after spaces and hyphens are removed, 04 and 8 digits or +614 and
 * 8 digits. So "0412 345 678", "0412-345-678", "+61 412 345 678" and "+61412345678" are all valid; the server
 * normalises them to one stored format.
 */
export const MOBILE_PATTERN = '(0[ \\-]?4([ \\-]?[0-9]){8}|\\+[ \\-]?6[ \\-]?1[ \\-]?4([ \\-]?[0-9]){8})';
