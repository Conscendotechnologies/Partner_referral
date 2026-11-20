import { MOBILE_PATTERN } from '../mobilePattern';

// The browser anchors a `pattern` attribute to the whole value, so the test does the same.
const matches = (value) => new RegExp(`^(?:${MOBILE_PATTERN})$`).test(value);

// What PR_ReferralService accepts: spaces/hyphens/brackets removed, then ^(04\d{8}|\+614\d{8})$.
const serverAccepts = (value) => /^(04\d{8}|\+614\d{8})$/.test(value.replace(/[\s\-()]/g, ''));

describe('prReferralForm mobile pattern (D5)', () => {
    const valid = [
        '0412345678',
        '0412 345 678',
        '0412-345-678',
        '04 1234 5678',
        '+61412345678',
        '+61 412 345 678', // S02-TC-06: rejected before this fix
        '+61 412 000 204',
        '+61-412-345-678'
    ];
    const invalid = [
        '0212345678', // landline
        '041234567', // 7 digits after 04
        '04123456789', // 9 digits after 04
        '+61212345678', // +61 landline
        '61412345678', // no +
        '+6141234567', // 7 digits after +614
        '0412  345 678', // two separators in a row
        '0412 345 678 ', // trailing space
        '04123x5678',
        ''
    ];

    it.each(valid)('accepts %p', (value) => {
        expect(matches(value)).toBe(true);
    });

    it.each(invalid)('rejects %p', (value) => {
        expect(matches(value)).toBe(false);
    });

    it.each([...valid, ...invalid.filter((v) => !/\s{2}|\s$/.test(v))])(
        'agrees with the server rule for %p',
        (value) => {
            expect(matches(value)).toBe(serverAccepts(value));
        }
    );
});
