# School Management System (Full-Stack) - HUMAN VERSION

This workspace contains two apps that work together:

- `school-mgmt-backend` → Rails 8 API (PostgreSQL, Devise JWT)
- `school-management-system` → React + TypeScript + Vite frontend

This guide explains architecture, data model, business rules, and request/feature flows.

---

## 1) Tech Stack

### Backend (`school-mgmt-backend`)

- Ruby on Rails `~> 8.1.2` (API-only)
- PostgreSQL (`pg`)
- Auth: `devise` + `devise-jwt`
- CORS: `rack-cors`
- Authorization support gem: `pundit` (role checks are mostly manual in controllers)
- Testing: `rspec-rails`, `factory_bot_rails`

### Frontend (`school-management-system`)

- React `19`, TypeScript, Vite
- Routing: `react-router-dom`
- API calls via native `fetch` wrapper
- UI icons: `lucide-react`
- Local storage for auth token + user snapshot

---

## 2) Repository Layout

### Backend

- `app/models` → domain entities and validations
- `app/controllers/api/v1` → JSON REST API controllers
- `app/controllers/users` → Devise sessions/registrations overrides
- `config/routes.rb` → API + auth routes
- `db/schema.rb` → current database schema

### Frontend

- `src/context` → `AuthContext`, `ToastContext`
- `src/services` → typed API client/service layer
- `src/pages` → role-specific screens (admin/student/teacher)
- `src/utils/gradeCalculations.ts` → grading formulas

---

## 3) Authentication & Authorization Flow

## Backend auth flow (JWT)

Authentication is configured in `User` model and Devise initializer:

```rb
# app/models/user.rb
devise :database_authenticatable, :registerable,
			 :recoverable, :rememberable, :validatable,
			 :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist
```

```rb
# config/initializers/devise.rb
config.jwt do |jwt|
	jwt.secret = Rails.application.credentials.devise_jwt_secret_key!
	jwt.dispatch_requests = [["POST", %r{^/users/sign_in$}]]
	jwt.revocation_requests = [["DELETE", %r{^/users/sign_out$}]]
	jwt.expiration_time = 1.day.to_i
end
```

All API controllers are protected by `authenticate_user!`:

```rb
# app/controllers/api/v1/base_controller.rb
before_action :authenticate_user!
```

### Frontend auth flow

- Login request: `POST /users/sign_in` with `{ user: { email, password } }`
- Frontend reads `Authorization: Bearer <jwt>` response header
- Stores token in `localStorage` as `authToken`
- `apiFetch` sends token on every request
- On `401`, token is removed and user is redirected to `/login`

```ts
// src/services/auth.service.ts
const authHeader = response.headers.get('Authorization');
const token = authHeader?.replace('Bearer ', '');
setAuthToken(token!);
```

---

## 4) Domain Model (Backend)

Core tables from `db/schema.rb`:

- `users` (email, encrypted_password, role, name)
- `students` (user_id, department_id, semester, max_credit_per_semester)
- `teachers` (user_id, department_id, designation)
- `departments` (name, code)
- `courses` (title, credit_hours, department_id, teacher_id)
- `enrollments` (student_id, course_id, status, semester)
- `grades` (student_id, course_id)
- `grade_items` (grade_id, category, max_marks, obtained_marks)
- `jwt_denylists` (token revocation list)

## Relationship map

- `User` has_one `Student` / has_one `Teacher`
- `Student` belongs_to `User`, belongs_to `Department`
- `Teacher` belongs_to `User`, belongs_to `Department`
- `Department` has_many `Students`, `Teachers`, `Courses`
- `Course` belongs_to `Department`, belongs_to `Teacher`
- `Enrollment` belongs_to `Student`, belongs_to `Course`
- `Grade` belongs_to `Student`, belongs_to `Course`
- `GradeItem` belongs_to `Grade`

---

## 5) Business Rules (Important)

## Role enum

```rb
enum :role, { student: 0, teacher: 1, admin: 2 }
```

## Enrollment status enum

```rb
enum :status, { pending: 0, approved: 1, rejected: 2, completed: 3, dropped: 4, withdrawn: 5 }
```

## Teacher course limit

- A teacher can be assigned max 3 courses.
- Enforced both in model (`Course#teacher_course_limit`) and controller checks.

## Credit-hour limit

- Default max per semester: `21` (or student-specific `max_credit_per_semester`).
- Enrollment request/approval validates credit limit.

## Semester cap

- Student semester must stay within `1..12`.
- Promotion blocked if pending/approved enrollments exist.

## Grade/grade-item constraints

- One grade per `(student_id, course_id)`.
- Midterm requires at least 2 assignments + 2 quizzes.
- Final requires midterm + at least 4 assignments + 4 quizzes.
- Midterm/final must be unique per grade.

---

## 6) Grading, GPA, SGPA, CGPA

Frontend formulas are in `src/utils/gradeCalculations.ts` and pages `student.tsx` / `results.tsx`.

## Weighted total (%)

Weightage:

- assignments: `10%`
- quizzes: `15%`
- midterm: `25%`
- final: `50%`

Formula:

$$
Total\% = (A\% \times 0.10) + (Q\% \times 0.15) + (M\% \times 0.25) + (F\% \times 0.50)
$$

## GPA points mapping (4.0 scale)

- `>=85`: 4.0
- `>=80`: 3.7
- `>=75`: 3.3
- `>=70`: 3.0
- `>=65`: 2.7
- `>=60`: 2.3
- `>=55`: 2.0
- `>=50`: 1.7
- `<50`: 0.0

## Letter grades

- `A, A-, B, B-, C, C-, D, D-, F` with the same threshold boundaries as GPA above.

## SGPA (semester GPA)

$$
SGPA = \frac{\sum (CourseGPA \times CreditHours)}{\sum CreditHours}
$$

## CGPA (overall)

$$
CGPA = \frac{\sum (CourseGPA \times CreditHours)}{\sum CreditHours}
$$

Computed across all graded completed courses.

---

## 7) Key API Endpoints

Defined in `config/routes.rb`.

## Auth

- `POST /users/sign_in`
- `DELETE /users/sign_out`
- `POST /users` (registration)

## Core resources

- `/api/v1/departments`
- `/api/v1/students` (+ `PATCH /:id/promote_semester`)
- `/api/v1/teachers`
- `/api/v1/courses`
- `/api/v1/enrollments`
- `/api/v1/grades`
- `/api/v1/grade_items`

## Enrollment actions

- `POST /api/v1/enrollments/request_enrollment`
- `PATCH /api/v1/enrollments/:id/approve`
- `PATCH /api/v1/enrollments/:id/reject`
- `PATCH /api/v1/enrollments/:id/complete`
- `PATCH /api/v1/enrollments/:id/drop`
- `PATCH /api/v1/enrollments/:id/withdraw`
- `POST /api/v1/enrollments/announce_results`

---

## 8) Feature Flows (End-to-End)

## A) Login flow

1. User submits credentials on frontend login page.
2. Backend Devise authenticates and returns user JSON + JWT in `Authorization` header.
3. Frontend stores token + user info in localStorage.
4. Protected routes become accessible based on role.

## B) Student enrollment request flow

1. Student opens available courses (`StudentPage`).
2. Frontend checks client-side credit cap before request.
3. `POST /enrollments/request_enrollment` creates `pending` enrollment.
4. Backend validates duplicate enrollments, semester cap, and credit limit.

## C) Admin enrollment processing flow

1. Admin opens enrollment manager.
2. Approve/reject pending requests.
3. Approved records can later be marked completed or dropped.

## D) Teacher grading flow

1. Teacher opens `TeacherGradesPage` for one of their assigned courses.
2. For each student, teacher creates grade record (if absent) and adds grade items.
3. Backend enforces category prerequisites and uniqueness.
4. Student results page derives total %, letter grade, and GPA.

## E) Announce results flow (admin)

1. Admin triggers “Announce Results”.
2. Backend checks all approved enrollments have a final grade item.
3. If incomplete: returns list of incomplete courses.
4. If complete: marks approved enrollments as `completed` and promotes semester (up to semester 12).

---

## 9) Frontend Architecture

## Context providers

- `AuthProvider`:
	- Hydrates session from localStorage on app start
	- Exposes `currentUser`, `userData`, `login`, `logout`
- `ToastProvider`:
	- Global success/error/warning/info toasts
	- Promise-based confirm modal (`await toast.confirm(...)`)

## Routing & role guarding

- `App.tsx` defines routes for admin/student/teacher pages.
- `ProtectedRoute` enforces allowed roles and redirects to proper home.

## Service layer

- All API calls are centralized in `src/services/*`.
- `apiFetch` injects auth headers and handles `401` globally.

---

## 10) Setup & Run

## Prerequisites

- Ruby 3.x
- Bundler
- PostgreSQL
- Node.js 18+ (recommended)
- npm

## Backend startup

```bash
cd school-mgmt-backend
bundle install
bin/rails db:create db:migrate db:seed
bin/rails s
```

Backend default URL: `http://localhost:3000`

## Frontend startup

```bash
cd school-management-system
npm install
npm run dev
```

Frontend default URL: `http://localhost:5173`

Create `.env` in frontend if needed:

```env
VITE_API_BASE_URL=http://localhost:3000
```

---

## 11) Notes & Known Design Decisions

- API is JWT-based; no Rails cookie session used for SPA flow.
- CORS currently allows all origins (`origins "*"`) for development convenience.
- Some admin/role authorization is controller-level checks (for example `require_admin!`).
- Backend is API-only (`config.api_only = true`).
- Enrollments endpoint excludes REST `destroy` route in routing.

---

## 12) Quick Data Lifecycle Summary

1. Admin creates departments, teachers, students, and courses.
2. Student requests enrollment (`pending`).
3. Admin approves enrollment (`approved`).
4. Teacher submits grade items throughout semester.
5. Admin announces results:
	 - validations pass,
	 - enrollments become `completed`,
	 - student semesters are promoted.
6. Student sees updated transcript, GPA, SGPA, and CGPA in result pages.
