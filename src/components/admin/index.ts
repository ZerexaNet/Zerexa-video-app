/**
 * Barrel export for admin back-office components.
 *
 * The admin-shell imports each section view through this file so
 * the import statements stay compact and adding a new section is
 * a one-line change here.
 */

export { AdminShell, AdminRefreshButton } from "./admin-shell";
export { AdminDashboard } from "./admin-dashboard";
export { AdminVideos } from "./admin-videos";
export { AdminUsers } from "./admin-users";
export { AdminReports } from "./admin-reports";
export { AdminAnnouncements } from "./admin-announcements";
export {
  AdminSectionHeader,
  StatCard,
  StatusBadge,
  EmptyState,
  ErrorBanner,
  AdminTable,
  Th,
  Td,
  asArray,
} from "./admin-shared";
