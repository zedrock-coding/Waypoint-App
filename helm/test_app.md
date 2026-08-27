# Helm Feature Verification Checklist ✅

This document serves as a comprehensive manual testing guide to ensure every feature of **Helm** works exactly as designed. Go through this list after any major update.

---

## 🤖 1. AI Command Center (Voice & Text)
- [ ] **Manual Entry**: Type "Fix the server by tomorrow" in the bottom command bar and hit Send. 
  - *Expected*: A task appears with "Fix the server" as the title and tomorrow's date.
- [ ] **Voice Command**: Tap the Mic icon, say "New task high priority Buy groceries for today", and stop listening.
  - *Expected*: Task created with **High Priority** and today's date.
- [ ] **Context Awareness**: Type "Assign this to [Teammate Name] in [Community Name]".
  - *Expected*: The task is automatically created inside that community and assigned to that specific person.
- [ ] **Visual Feedback**: Command bar glows **Red** while listening and **Primary Color** while processing.

## 📅 2. Interactive Calendar
- [ ] **Navigation**: Tap "Calendar" in the sidebar/drawer.
  - *Expected*: Monthly calendar view loads.
- [ ] **Task Badges**: Check days with known tasks.
  - *Expected*: Small teal dots appear under dates that have tasks due.
- [ ] **Filtering**: Tap a specific date.
  - *Expected*: The list below the calendar filters to show only tasks due on that day.
- [ ] **Reset**: Tap the "All Tasks" chip.
  - *Expected*: The filter clears and all tasks with due dates are shown.

## 👥 3. Community & Team Management
- [ ] **Creation**: Click "New Community", enter a name, hit Create.
  - *Expected*: You are taken to the new workspace and your role is automatically set to **Owner**.
- [ ] **Invite Logic**: Go to "Manage Members", copy the invite link.
  - *Expected*: Link format is `helm://invite?communityId=UUID`.
- [ ] **Role Hierarchy (RBAC)**:
  - [ ] **Owner**: Can promote/demote members and remove everyone except themselves.
  - [ ] **Admin**: Can manage standard members but cannot demote other Admins or the Owner.
  - [ ] **Member**: Cannot see management controls or edit tasks created by Admins/Owners.
- [ ] **Leaving**: Join a community with a second account and tap "LEAVE".
  - *Expected*: Account is removed. If you were the last member, the community is deleted from Supabase.

## ✏️ 4. Task Lifecycle (CRUD & Sync)
- [ ] **Creation**: Add a task via the FAB (+ button).
  - *Expected*: Task appears instantly in the list (Local Hive update).
- [ ] **Cloud Sync**: Check the **Supabase Dashboard** after creating a task.
  - *Expected*: A new row appears in the `tasks` table with the correct UUID.
- [ ] **Reordering**: Long-press the drag handle (drag indicator) and move a task.
  - *Expected*: The order is saved and persists after an app restart.
- [ ] **Subtasks**: Open task details, add 3 subtasks, and check 1 off.
  - *Expected*: Progress is saved and synced to the cloud.

## 💬 5. Discussion & 2-Comment Rule
- [ ] **Messaging**: Open a community task, post a comment.
  - *Expected*: Comment appears instantly with your name and avatar.
- [ ] **Limit Enforcement**: Post a second comment.
  - *Expected*: The input field locks and the "Limit Reached" banner appears.
- [ ] **Reset Logic**: Edit the task title or change its status (e.g., Todo -> Done).
  - *Expected*: The comment input field unlocks (2 new slots granted).

## 🖼️ 6. Profile & Identity
- [ ] **Avatar Upload**: Go to Account Settings, tap the Camera icon, and select a photo.
  - *Expected*: Photo is compressed on-device and uploaded to Supabase Storage.
- [ ] **Global Refresh**: Check the dashboard header and community list.
  - *Expected*: Your new photo appears everywhere instantly.
- [ ] **Initials Fallback**: Use an account without a photo.
  - *Expected*: CircleAvatar displays your first two initials on a colored background.

## 🛠 7. Support & Navigation
- [ ] **Feedback Portal**: Tap "Support & Feedback" in the sidebar.
  - *Expected*: External browser opens `https://helm-omega-blue.vercel.app/feedback.html`.
- [ ] **Keyboard Shortcuts**: Press `Ctrl + N` (New Task) and `Esc` (Close Panel).
  - *Expected*: Actions trigger correctly without using the mouse.
- [ ] **Web Deep Linking**: Refresh the web app while on the `/calendar` page.
  - *Expected*: The page reloads correctly (no 404 error).
