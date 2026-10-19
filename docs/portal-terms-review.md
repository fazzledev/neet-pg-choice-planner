# Portal terms review: signing in to the MCC candidate portal on the candidate's behalf

Reviewed 2026-10-19. The question is whether it breaks any MCC, NIC or NBEMS rule for Choice Planner's server to sign in to `mcc.admissions.nic.in` for one consenting candidate. The human types the security pin and the OTP. The server stores the roll number and an encrypted SHA-256 hash of the password, which works as the password for the portal. It never locks choices.

## Sources read

| Document | URL |
|---|---|
| PG Information Bulletin 2026 (MD/MS/DNB), "DRAFT – V10 05102026", 123 pp | https://cdnbbsr.s3waas.gov.in/s3e0f7a4d0ef9b84b83b693bbf3feb8e6e/uploads/2026/10/202610082121348550.pdf |
| Candidate User Guide – NEET PG Counselling 2026, 56 pp | https://cdnbbsr.s3waas.gov.in/s3e0f7a4d0ef9b84b83b693bbf3feb8e6e/uploads/2026/10/202610121388624358.pdf |
| MCC notices of 28.09, 14.10 and 15.10.2026 (PwD, NRI corrigendum, seat matrix, PwD grievances), schedules | linked from https://mcc.nic.in/pg-medical-counselling/ (no relevant clauses) |
| Portal footer: Terms & Conditions, Privacy Policy, Hyperlink Policy, Disclaimer | https://mcc.admissions.nic.in/Applicant/FooterPoliciesPages/{TermsConditions,privacyPolicy,hyperlinkPolicy,disclaimer}.aspx |
| NBEMS NEET-PG Information Bulletin. The 2026 bulletin is not linked on natboard.edu.in or nbe.edu.in, so the 2025 edition was read as a proxy. | https://nbe.edu.in/IB/IB%20NEET-PG%202025.pdf |

The MCC pages have no separate PG "Scheme of Counselling" or FAQ PDF for 2026. The scheme and the FAQs (chapter 13) are both inside the Information Bulletin. `robots.txt` on the portal returns a WAF "Request Rejected" page, so it states no crawl policy.

## Relevant clauses

### 1. Password confidentiality (the closest clause)

- **PG Information Bulletin 2026, ch. 13.1 FAQ Q.4, p. 49.** The bulletin advises candidates "to keep the password ... confidential to them till the end". It adds that sharing the password "can result in its misuse by somebody else, leading to even exclusion of genuine candidate".
- **Candidate User Guide 2026, §Registration (password creation), p. 7.** "Candidates are advised not to disclose or share their password with anybody."
- **How this applies:** Both clauses are worded as advice ("advised"). Neither sets a penalty, and neither defines sharing as misconduct. The only consequence they name is the practical risk that someone else misuses the password, which is a risk to the candidate. Our tool stores a password-equivalent hash, so the candidate has in substance shared his credential with the operator (his brother) and the server. This goes against the advice but breaks no prohibition. The risk the clause warns about, an unwanted lock or change of choices, is real, so the safeguards below matter.

### 2. Filling forms "on their own", not through agents or third parties

- **PG Information Bulletin 2026, §2.8, p. 6.** Candidates are "advised to fill the application form on their own/self ... not through any agent or third party."
- **How this applies:** This covers the registration/application form, which is already submitted. It does not cover reading the dashboard or choice lists. It is also advice and carries no penalty. The target is commercial agents (see §2.17). A sibling running a private tool for one candidate, with consent, is outside the obvious intent. If the tool ever edited choices or submitted forms, it would move closer to the spirit of this clause.

### 3. Agents and touts

- **PG Information Bulletin 2026, §2.17, p. 7.** It warns that "persons/agents have claimed to provide a seat". MCC disclaims responsibility for such fraud.
- **NBEMS NEET-PG 2025 Bulletin, §9.5–9.6, p. 93.** Report touts promising "undue favour".
- **How this applies:** These clauses deal with fraud and seat-selling. They do not apply to our tool.

### 4. Candidate responsibility; locked choices are final

- **PG Information Bulletin 2026, §2.12–2.14, p. 7.** Information entered is "self-certified". "Choices once locked cannot be modified."
- **PG Information Bulletin 2026, FAQ Q.28–29, p. 57.** Unlocked saved choices are auto-locked at the deadline.
- **How this applies:** Anything the tool does under the candidate's login is the candidate's act and cannot be undone. Even if locking stays manual, choices saved through the tool would be auto-locked at the deadline. The candidate bears every error.

### 5. OTP and password gates on sensitive actions

- **Candidate User Guide 2026, §14 Choice Filling, pp. 30–32.** Choice filling needs the password again plus an OTP to the "registered mobile number or Email ID".
- **Candidate User Guide 2026, §16 Choice Locking, pp. 35–36.** Locking needs the password plus an OTP.
- **PG Information Bulletin 2026, §2.18, p. 7.** OTPs go only to the registered mobile and email.
- **How this applies:** The portal is built so that the person who holds the phone authorises each sensitive action. Our flow keeps the human (the candidate or his brother) relaying the OTP, which matches the design. Running OTP entry automatically, for example by forwarding SMS to the server, would defeat that control.

### 6. Session tied to IP; login trails are visible

- **PG Information Bulletin 2026, FAQ Q.25, p. 57.** "the IP address which is being monitored will change and session expired".
- **Candidate User Guide 2026, §Dashboard header (c)–(d), p. 12.** The candidate can view "Last Activity Details" and "Login Trails".
- **How this applies:** MCC logs each login with its IP. The candidate (and MCC) will see the server's datacenter IP, not his home ISP. This is not a violation, but it makes the tool visible. If a session is created in one place and used from another IP, it will break. Q.25 even suggests logging in "from other computer from which other candidate(s) has logged in", which shows that shared machines and cyber cafés are expected and tolerated.

### 7. Portal footer policies (NIC e-Counselling)

- **Terms & Conditions.** NIC is not liable for loss "arising out of ... the use of this platform". Indian law applies, under the jurisdiction of Indian courts.
- **Privacy Policy.** The platform records "IP addresses, domain name, browser type" etc. Data is shared only when a "law enforcement agency requests".
- **Hyperlink Policy.** "we do not permit our pages to be loaded into frames on your site."
- **Disclaimer.** Content is "for information purposes only".
- **How this applies:** None of these pages has an acceptable-use clause, and none bans automation, scraping, bots or third-party access. The only concrete restriction is the no-framing rule. Choice Planner must never iframe portal pages. It should show its own rendering of the data or link out in a new window.

### 8. NBEMS hacking / IT-tampering clauses (exam-side only)

- **NBEMS NEET-PG 2025 Bulletin, §9.27–9.28, p. 95.** It lists as unfair means "Hacking or attempting to hack or causing interference with the website of NBEMS". Penalty under §9.10: "penal action and cancellation of the candidature".
- **How this applies:** These clauses cover NBEMS and its technology partners' systems (natboard, the exam portal). The MCC portal is run by DGHS/NIC, so they do not reach it. They are still the strongest wording anywhere near this question. If request volume ever looked like "interference", or if the tool got around a control such as the captcha or OTP, a hostile reader could frame it this way. The 2026 NBEMS bulletin could not be fetched, so check its equivalent chapter if it turns up.

### 9. Background law (not from the documents)

The IT Act 2000 §43 and §66 penalise access to a computer system "without permission of the owner". Our tool signs in with the account holder's own credential and his consent. It defeats no security control: a human solves the captcha and enters the OTP. On these facts it is hard to call that unauthorised access. This is not legal advice.

## Bottom line

**Grey area. No explicit violation was found.** No MCC, NIC or NBEMS document read here bans automated access, bots, scripts or a delegate signing in with consent. Nor do any of them set a penalty for sharing a password. The relevant clauses are advisory:

- keep the password confidential (Bulletin FAQ Q.4, p. 49; User Guide p. 7);
- fill the form yourself, not through an agent or third party (Bulletin §2.8, p. 6).

Our design goes against the spirit of the password advice. It does not break a stated rule. The real exposure is practical: misuse, an unwanted save or lock that cannot be reversed, and a visible datacenter IP in the login trail. It is not disciplinary.

## Suggestions to stay on the right side

1. Keep the tool read-only on the portal. It should never save, reorder or lock choices, and never submit willingness or withdrawal. The candidate types those into the official portal himself. This keeps §2.8 ("on their own/self") and §2.12–2.14 (self-certified, irreversible) cleanly on his side.
2. Always relay the security pin and OTP by hand. Never solve the captcha automatically, and never forward SMS or email OTPs to the server.
3. Get the candidate's written consent, kept in the repo or in an email. It should name the operator (his brother) and the read-only scope.
4. Delete the stored password hash and roll number when counselling ends (after the final round), or keep them only for the session. Tell the candidate he can rotate his password with "Change Password" at any time, and have him do so when counselling ends.
5. Keep request volume human-scale, at the current handful per session with no polling loops. Back off immediately on any WAF "Request Rejected" page.
6. Never frame portal pages, per the Hyperlink Policy.
7. Tell the candidate that the server's IP will show in "Login Trails", so that he can tell it apart from a real intrusion.
8. Check whether the final (non-draft) 2026 PG Bulletin and the 2026 NBEMS bulletin add an anti-automation or credential-sharing penalty. The bulletin read here is "DRAFT – V10".
