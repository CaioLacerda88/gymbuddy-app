# Privacy Policy

**Last updated: 2026-04-10**

This Privacy Policy describes how GymBuddy ("we", "us", or "our") collects, uses, and protects your information when you use the GymBuddy mobile and web application (the "App").

## 1. Who We Are

GymBuddy is a fitness tracking application that helps you log workouts, track personal records, and manage your exercise library. If you have questions about this policy, contact us at **support@gymbuddy.app**.

## 2. Information We Collect

We collect only the information you provide directly and a small number of in-app events used to improve the App (see "Usage Events" below). GymBuddy does not use advertising SDKs, ad networks, or analytics services that share your data with advertisers. We use Sentry to receive crash reports when the App encounters an unhandled error — see Section 5.

### Account Information
- **Email address** — used for authentication and account recovery.
- **Password** — stored as a hashed value by Supabase Auth. We never see or store your plain-text password.
- **Google OAuth identifier** — if you sign in with Google, we receive a unique identifier and your email address from Google.

### Profile Information
- Display name
- Weight unit preference (kilograms or pounds)
- Body weight, if you choose to log it
- Training goals (e.g. weekly workout frequency)

### Fitness Data
- Workout history: exercises, sets, reps, weight, dates, notes, and workout duration
- Customizations you make to the exercise library
- Personal records detected by the App

### Usage Events

To understand how the App is used and improve reliability, we log a small set of in-app events (for example: when you sign up, finish a workout, or set a personal record) to our own database alongside your other data. These events record the action and its basic parameters (e.g. workout duration, exercise count). They never contain your email address, display name, workout notes, or any free-text input. These events are tied to your account and deleted when you delete your account.

## 3. How We Collect Information

All information is collected directly from the App based on actions you take (signing up, logging workouts, editing your profile, etc.). We do not track your location or device activity. The usage events described in Section 2 are collected to improve the App and are the only form of usage tracking.

## 4. How Your Data Is Stored

Your data is stored on Supabase infrastructure:

- **Database:** PostgreSQL with row-level security — each user can only access their own data.
- **In transit:** encrypted via TLS.
- **At rest:** encrypted by Supabase at the storage layer.

Supabase may process data in the regions it operates. See [supabase.com/privacy](https://supabase.com/privacy) for Supabase's own policies.

## 5. Third Parties

GymBuddy uses the following third-party services:

- **Supabase** — hosting, authentication, and database.
- **Google** — OAuth authentication only, if you choose to sign in with Google.
- **Sentry** — crash reporting only. When the App encounters an unhandled error, a stack trace, the environment (OS, app version), and your account ID (no email, no name, no IP address) are sent to sentry.io so we can diagnose and fix the bug. You can disable this at any time in **Profile → Privacy → Send crash reports**. For Sentry's own policies, see [sentry.io/privacy](https://sentry.io/privacy/).

We do **not** use advertising networks. We do **not** sell your data. We do **not** share your fitness data with insurers, employers, or anyone else.

## 6. Your Rights

Depending on your jurisdiction, you may have the following rights regarding your personal data:

- **Access** — request a copy of the data we hold about you.
- **Rectification** — correct inaccurate data directly in the App or by contacting us.
- **Erasure** — delete your account and all associated data (see Section 7).
- **Data portability** — request your workout history in a machine-readable format.
- **Restriction of processing** — request that we limit how we use your data.

To exercise any of these rights, contact us at the email above.

## 7. Account Deletion

You can delete your account at any time through **Profile → Manage Data → Delete Account**, or by contacting support. Deletion is permanent: all workout history, profile information, and account credentials are removed within 30 days of your request. Backups containing your data are purged on the same schedule.

## 8. Children

GymBuddy is not directed to children under 13. Users in the European Economic Area must be at least 16 years old (or have verifiable parental consent where permitted by local law). We do not knowingly collect data from children below these ages. If you believe a child has provided us with personal information, contact us and we will delete it.

## 9. International Users

GymBuddy is available globally. Your data may be processed in any region where Supabase operates its infrastructure. By using the App, you consent to this processing.

## 10. Changes to This Policy

We may update this Privacy Policy from time to time. When we do, we will update the "Last updated" date at the top of this document. For material changes, we will notify you via the App or by email before the changes take effect.

## 11. Contact

Questions, concerns, or requests? Reach us at **support@gymbuddy.app**.
