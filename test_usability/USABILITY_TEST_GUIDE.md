# StillAlive - Usability Testing Guide 2026

## 1. Introduction

**StillAlive** is a user-centered personal safety mobile application that allows users to configure a safety timer. The user starts the timer before leaving home or beginning any solo activity and must check in before the timer expires. If the check-in does not happen in time, the system automatically triggers an emergency protocol — sending SMS messages, Telegram and/or Discord alerts to configured contacts, including the user's location, timer name, and event log.

In addition, the platform allows users to manage emergency contacts, customize messages, configure integrations with communication platforms (Telegram, Discord), export/import backups, and view the event history.

### What is a usability test?

In this test, you will explore the StillAlive application while completing a set of everyday tasks. The focus **is not on evaluating your abilities**. We are evaluating the application. There are no right or wrong answers. We want to observe how you use the platform naturally and understand what works well and what could be improved.

Thank you for participating in this StillAlive usability test. Your contribution is essential to improving the application experience. This document explains, in simple terms, everything you need to know before getting started.

### Objective

The objective of this test is to identify potential usability difficulties, evaluate the clarity of the interface, and understand how new users interact with the application during their first sessions, particularly in critical configuration contexts (emergencies, contacts, and integrations). The results collected will be used to identify improvements to the user experience and optimize the overall usability of the application.

<div class="page"/>

## 2. Before You Start

### What you need

- An Android mobile phone with internet access
- The application link: [Google Play](https://play.google.com/store/apps/details?id=com.appsbyrafa.stillalive)
- Approximately **15 to 30 minutes** available without interruptions
- A **Discord** or **Telegram** account for integration testing _(optional)_

### Recommendations

- Close other unnecessary applications before starting
- Turn **Airplane Mode on and then off** if you want to test SMS
- No prior preparation is required — **do not read manuals or tutorials before the test**
- You are free to explore the application between tasks
- If you have questions, think aloud — this is part of the test

> **Privacy**
> No personal data is collected or used for commercial purposes.

<div class="page"/>

## 3. How the Session Works

The session is divided into tasks that follow the natural journey of a new **StillAlive** user.

First, we will complete the **essential journey** (15–30 min). If there is enough time, we will continue with the optional tasks.

### Essential Journey (Required)

| Step | Task                       | Objective                                   | Success Criteria                              | Duration |
| ---- | -------------------------- | ------------------------------------------- | --------------------------------------------- | -------- |
| 1    | Splash → Onboarding → Home | Evaluate the first interaction with the app | User reaches Home without assistance          | 1–2 min  |
| 2    | Add first contact          | Test contact persistence                    | Contact is visible in the list                | 1–3 min  |
| 3    | Configure timer            | Validate the timer configuration flow       | Timer is active with a visible countdown ring | 3–6 min  |
| 4    | Perform check-in           | Measure ease of the primary action          | Check-in completed in less than 30 sec        | 1–3 min  |
| 5    | Cancel / pause timer       | Evaluate deactivation behavior              | Timer cancelled with visual feedback          | 0–1 min  |

<b>Estimated total: 13–20 min</b>

### Additional Journey (Optional)

| Step | Task                                   | Objective                                 | Success Criteria                              | Duration |
| ---- | -------------------------------------- | ----------------------------------------- | --------------------------------------------- | -------- |
| 6    | Configure Telegram/Discord integration | Evaluate the integration setup flow       | Integration activated and successfully tested | 5–7 min  |
| 7    | Customize alert message                | Test content customization                | Customized message saved                      | 2–5 min  |
| 8    | View event history                     | Measure clarity of historical information | User identifies events and their status       | 2–5 min  |
| 9    | Test backup/restore                    | Validate the export/import flow           | Backup generated and imported                 | 1–3 min  |

<b>Estimated additional time: 20–30 min</b>

<div class="page"/>

## 4. The 9 Test Steps

For each step, you will find a list of tasks to complete.

<table>
    <tr>
        <th colspan="3" style="text-align: left; font-size: 22px;">
            Step 1 — Splash → Onboarding → Home
        </th>
    </tr>
    <tr>
        <th>Tasks</th>
        <th>Success Metrics</th>
        <th>Points to Observe</th>
    </tr>
    <tr>
        <td>
            <ul>
                <li>Find the "Get Started" button or equivalent in the onboarding</li>
                <li>Go through all onboarding pages without assistance</li>
                <li>Identify the bottom navigation (Home, Contacts, History, Integrations, Settings)</li>
                <li>Return to the app after closing it and check its state</li>
            </ul>
        </td>
        <td>
            <ul style="list-style-type: '✓ ';">
                <li>Reaches the dashboard in less than 2 min</li>
                <li>No questions or confusion during initial navigation</li>
                <li>Recognizes the timer status (active/inactive)</li>
            </ul>
        </td>
        <td>
            <ul style="list-style-type: none;">
                <li>! Confusion with onboarding pages</li>
                <li>? Are the instructions clear?</li>
                <li>? Are the bottom navigation icons recognizable?</li>
            </ul>
        </td>
    </tr>
</table>

<table>
    <tr>
        <th colspan="3" style="text-align: left; font-size: 22px;">
            Step 2 — Add First Quick Contact
        </th>
    </tr>
    <tr>
        <th>Tasks</th>
        <th>Success Metrics</th>
        <th>Points to Observe</th>
    </tr>
    <tr>
        <td>
            <ul>
                <li>Navigate to Contacts using the bottom navigation</li>
                <li>Find a contact (you can search by name or phone number)</li>
                <li>Add the contact to the quick contacts list</li>
                <li>Verify that the contact has the quick contact status</li>
                <li>Return to Home and verify that the contact appears in the list</li>
            </ul>
        </td>
        <td>
            <ul style="list-style-type: '✓ ';">
                <li>Finds the contacts section in less than 30 sec</li>
                <li>Contact is added and visible in the list after saving</li>
                <li>Clear visual feedback after saving</li>
            </ul>
        </td>
        <td>
            <ul style="list-style-type: none;">
                <li>! User looks for the "Add" button in the wrong place</li>
                <li>? Is the distinction between contact types clear?</li>
                <li>? Is the automatically generated initials/avatar and color intuitive?</li>
            </ul>
        </td>
    </tr>
</table>

<table>
    <tr>
        <th colspan="3" style="text-align: left; font-size: 22px;">
            Step 3 — Configure Timer
        </th>
    </tr>
    <tr>
        <th>Tasks</th>
        <th>Success Metrics</th>
        <th>Points to Observe</th>
    </tr>
    <tr>
        <td>
            <ul>
                <li>Tap the button to start / create a timer</li>
                <li>Choose a duration (e.g., 30 minutes)</li>
                <li>Add recipients (contacts + integrations)</li>
                <li>Customize the emergency message <em>(optional)</em></li>
                <li>Start the timer</li>
            </ul>
        </td>
        <td>
            <ul style="list-style-type: '✓ ';">
                <li>Configures and starts the timer in less than 4 min</li>
                <li>Countdown ring is visible and readable</li>
                <li>"Active" status is clear in the UI</li>
            </ul>
        </td>
        <td>
            <ul style="list-style-type: none;">
                <li>! Confusion between "duration" and "grace period"</li>
                <li>? Is the logic of multiple recipients (SMS + Telegram) clear?</li>
                <li>? Is emergency message customization easy to find?</li>
            </ul>
        </td>
    </tr>
</table>

<table>
    <tr>
        <th colspan="3" style="text-align: left; font-size: 22px;">
            Step 4 — Cancel the Timer
        </th>
    </tr>
    <tr>
        <th>Tasks</th>
        <th>Success Metrics</th>
        <th>Points to Observe</th>
    </tr>
    <tr>
        <td>
            <ul>
                <li>With the timer active, find the "Cancel" button</li>
                <li>Observe the visual feedback after cancellation</li>
                <li>Verify whether the timer status changes</li>
            </ul>
        </td>
        <td>
            <ul style="list-style-type: '✓ ';">
                <li>Cancellation completed in less than 30 seconds</li>
                <li>Clear visual feedback after cancellation (e.g., ring returns to the beginning, notification)</li>
                <li>Timer status is updated correctly</li>
            </ul>
        </td>
        <td>
            <ul style="list-style-type: none;">
                <li>! Cancel button is in an unexpected location</li>
                <li>? Does the user understand that the timer was "reset" or "completed"?</li>
                <li>? Is audio/haptic feedback present and useful?</li>
            </ul>
        </td>
    </tr>
</table>

<table>
    <tr>
        <th colspan="3" style="text-align: left; font-size: 22px;">
            Step 5 — Pause the Timer
        </th>
    </tr>
    <tr>
        <th>Tasks</th>
        <th>Success Metrics</th>
        <th>Points to Observe</th>
    </tr>
    <tr>
        <td>
            <ul>
                <li>Start a new timer</li>
                <li>Decide to pause it after a few minutes</li>
                <li>Look for the pause button</li>
                <li>Observe what happens after pausing (history, status)</li>
            </ul>
        </td>
        <td>
            <ul style="list-style-type: '✓ ';">
                <li>Pauses the timer in less than 2 minutes</li>
                <li>Clear visual feedback after pausing</li>
                <li>History is updated correctly</li>
            </ul>
        </td>
        <td>
            <ul style="list-style-type: none;">
                <li>! Confusion between "cancel" and "pause"</li>
                <li>? Is it clear that the timer was paused (rather than falsely cancelled)?</li>
                <li>? Is the protection password (if configured) requested?</li>
            </ul>
        </td>
    </tr>
</table>

<table>
    <tr>
        <th colspan="3" style="text-align: left; font-size: 22px;">
            Step 6 — Configure Telegram/Discord Integration
        </th>
    </tr>
    <tr>
        <th>Tasks</th>
        <th>Success Metrics</th>
        <th>Points to Observe</th>
    </tr>
    <tr>
        <td>
            <ul>
                <li>Navigate to Integrations</li>
                <li>Select Telegram or Discord</li>
                <li>Enter the Bot Token</li>
                <li>Test the connection</li>
                <li>Observe the "active" / "failed" status</li>
            </ul>
        </td>
        <td>
            <ul style="list-style-type: '✓ ';">
                <li>Connects to the integration in less than 6 min</li>
                <li>Integration status is visible (active/failed)</li>
                <li>Message test completed successfully</li>
            </ul>
        </td>
        <td>
            <ul style="list-style-type: none;">
                <li>! Confusion between "token" and "bot ID"</li>
                <li>? Does the user know where to find the token (e.g., @BotFather)?</li>
                <li>? Are error messages clear when the token is invalid?</li>
            </ul>
        </td>
    </tr>
</table>

<table>
    <tr>
        <th colspan="3" style="text-align: left; font-size: 22px;">
            Step 7 — Customize Alert Message
        </th>
    </tr>
    <tr>
        <th>Tasks</th>
        <th>Success Metrics</th>
        <th>Points to Observe</th>
    </tr>
    <tr>
        <td>
            <ul>
                <li>Navigate to Settings → Emergency Message</li>
                <li>Enter a new default message</li>
                <li>Save and verify</li>
            </ul>
        </td>
        <td>
            <ul style="list-style-type: '✓ ';">
                <li>Edits and saves the message in less than 3 min</li>
                <li>Customized message appears during tests</li>
            </ul>
        </td>
        <td>
            <ul style="list-style-type: none;">
                <li>! User looks for the option in the wrong place</li>
                <li>? Is the character limit indicated?</li>
            </ul>
        </td>
    </tr>
</table>

<table>
    <tr>
        <th colspan="3" style="text-align: left; font-size: 22px;">
            Step 8 — View Event History
        </th>
    </tr>
    <tr>
        <th>Tasks</th>
        <th>Success Metrics</th>
        <th>Points to Observe</th>
    </tr>
    <tr>
        <td>
            <ul>
                <li>Navigate to History</li>
                <li>Identify recent events</li>
                <li>Distinguish between "timer completed" and "alert sent"</li>
                <li>Tap an event to view details (time, destination, location)</li>
            </ul>
        </td>
        <td>
            <ul style="list-style-type: '✓ ';">
                <li>Finds the history in less than 30 sec</li>
                <li>Understands the status of each event</li>
                <li>Details are readable when tapping an event</li>
            </ul>
        </td>
        <td>
            <ul style="list-style-type: none;">
                <li>! Confusion between "alert" and "check-in"</li>
                <li>? Are colors/icons used to clearly distinguish statuses?</li>
                <li>? Is the location displayed in a useful way?</li>
            </ul>
        </td>
    </tr>
</table>

<table>
    <tr>
        <th colspan="3" style="text-align: left; font-size: 22px;">
            Step 9 — Test Backup / Restore
        </th>
    </tr>
    <tr>
        <th>Tasks</th>
        <th>Success Metrics</th>
        <th>Points to Observe</th>
    </tr>
    <tr>
        <td>
            <ul>
                <li>Navigate to Settings → Backup</li>
                <li>Export the backup</li>
                <li>Verify that the file is created</li>
                <li><em>(Optional)</em> Create a new timer and re-import the backup</li>
            </ul>
        </td>
        <td>
            <ul style="list-style-type: '✓ ';">
                <li>Exports the backup in less than 3 min</li>
                <li>Backup file is created and accessible</li>
                <li>Re-import works correctly (if tested)</li>
            </ul>
        </td>
        <td>
            <ul style="list-style-type: none;">
                <li>! Confusion between "export" and "import"</li>
                <li>? Is the file format (.zip) clear?</li>
                <li>? Does the user understand where the file is saved?</li>
            </ul>
        </td>
    </tr>
</table>

<div class="page"/>

## 5. Independent Exploration

After completing the main tasks, the user will have a few minutes to freely explore the **StillAlive** application. The objective of this phase is to observe the user's natural behavior when there are no specific instructions, allowing us to understand which features attract the most interest and how the user navigates the application spontaneously.

During this period, the user may:

- Access any section of the application
- Explore advanced settings (themes, location, QR Code)
- Repeat actions performed previously
- Try features that were not introduced

This phase helps identify whether the application's structure is intuitive and whether the interface elements encourage exploration and discovery of features.

<div class="page"/>

## 6. Post-Test Questionnaire

After completing all tasks and the exploration phase, we ask the participant to complete a short usability questionnaire. The objective of this questionnaire is to gather the user's opinion about their overall experience with the application, including aspects related to ease of use, interface clarity, and overall satisfaction.

The answers provided will help the development team better understand the user experience and identify potential improvements to the application.

**Questionnaire link:**
<https://forms.gle/ZyNgKkBRcGimXg8EA>

The questionnaire takes approximately **3 to 6 minutes** to complete, and all responses will be used solely for evaluation and improvement of the platform.

Thank you again for participating and for contributing to improving the **StillAlive** experience.
