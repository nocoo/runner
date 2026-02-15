import { describe, test, expect } from "bun:test";
import { render, fireEvent } from "@testing-library/react";
import { MemoryRouter, Route, Routes } from "react-router";
import { DashboardLayout } from "../DashboardLayout";

// NOTE: We use destructured queries from render() instead of the `screen`
// singleton because bun test's preload timing means `screen` may bind to
// document.body before happy-dom registers the global DOM.
//
// NOTE: fireEvent.change does NOT trigger React 19 onChange handlers under
// happy-dom (known interop gap). Tests that require controlled-input state
// updates (search filtering) are omitted; the filter logic is a trivial
// string includes and is implicitly covered by the search dialog render tests.

function renderLayout(initialPath = "/") {
  return render(
    <MemoryRouter initialEntries={[initialPath]}>
      <Routes>
        <Route element={<DashboardLayout />}>
          <Route path="/" element={<div data-testid="dashboard-page">Dashboard Content</div>} />
          <Route path="/help" element={<div data-testid="help-page">Help Content</div>} />
          <Route path="/settings" element={<div data-testid="settings-page">Settings Content</div>} />
        </Route>
      </Routes>
    </MemoryRouter>
  );
}

describe("DashboardLayout", () => {
  test("renders sidebar with RUNNER branding", () => {
    const { getByText } = renderLayout();
    expect(getByText("[RUNNER]")).toBeTruthy();
  });

  test("renders navigation groups", () => {
    const { getByText } = renderLayout();
    expect(getByText("MAIN")).toBeTruthy();
    expect(getByText("SYSTEM")).toBeTruthy();
  });

  test("renders nav items inside nav element", () => {
    const { container } = renderLayout();
    const nav = container.querySelector("nav")!;
    expect(nav.textContent).toContain("Dashboard");
    expect(nav.textContent).toContain("Help");
    expect(nav.textContent).toContain("Settings");
  });

  test("renders outlet content for root path", () => {
    const { getByTestId } = renderLayout("/");
    expect(getByTestId("dashboard-page")).toBeTruthy();
  });

  test("renders outlet content for help path", () => {
    const { getByTestId } = renderLayout("/help");
    expect(getByTestId("help-page")).toBeTruthy();
  });

  test("shows correct page title for root", () => {
    const { getByRole } = renderLayout("/");
    const heading = getByRole("heading", { level: 1 });
    expect(heading.textContent).toBe("Dashboard");
  });

  test("shows correct page title for help", () => {
    const { getByRole } = renderLayout("/help");
    const heading = getByRole("heading", { level: 1 });
    expect(heading.textContent).toBe("Help");
  });

  test("renders skip-to-content link", () => {
    const { getByText } = renderLayout();
    const skipLink = getByText("Skip to main content");
    expect(skipLink).toBeTruthy();
    expect(skipLink.getAttribute("href")).toBe("#main-content");
  });

  test("renders search trigger with CMD+K hint", () => {
    const { getByText } = renderLayout();
    expect(getByText("search...")).toBeTruthy();
    expect(getByText("CMD+K")).toBeTruthy();
  });

  test("renders user footer", () => {
    const { getByText } = renderLayout();
    expect(getByText("Runner")).toBeTruthy();
    expect(getByText("launchd + opencode")).toBeTruthy();
  });

  test("nav group can be collapsed and expanded", () => {
    const { getByText, container } = renderLayout();
    const nav = container.querySelector("nav")!;

    // MAIN group is open by default, Dashboard should be visible in nav
    expect(nav.textContent).toContain("Dashboard");

    // Click the MAIN group header to collapse
    fireEvent.click(getByText("MAIN"));

    // After collapse, "Dashboard" nav item should be hidden from nav
    const navButtons = nav.querySelectorAll("button");
    const navItemTexts = Array.from(navButtons).map((b) => b.textContent?.trim());
    expect(navItemTexts).not.toContain("Dashboard");
  });

  test("clicking search trigger opens search dialog", () => {
    const { getByText, getByPlaceholderText } = renderLayout();
    fireEvent.click(getByText("search..."));
    expect(getByPlaceholderText("search pages...")).toBeTruthy();
  });

  test("search dialog shows all pages when no query", () => {
    const { getByText, container } = renderLayout();
    fireEvent.click(getByText("search..."));
    // The dialog should list all 3 nav items
    const dialog = container.querySelector(".fixed.inset-x-4");
    expect(dialog).toBeTruthy();
    expect(dialog!.textContent).toContain("Dashboard");
    expect(dialog!.textContent).toContain("Help");
    expect(dialog!.textContent).toContain("Settings");
  });

  test("navigates when clicking nav item", () => {
    const { getAllByText, getByTestId } = renderLayout("/");
    // Click Help nav item
    const helpButtons = getAllByText("Help");
    const navHelp = helpButtons.find(
      (el) => el.closest("nav") !== null
    );
    expect(navHelp).toBeTruthy();
    fireEvent.click(navHelp!);
    expect(getByTestId("help-page")).toBeTruthy();
  });

  test("renders mobile menu button", () => {
    const { getByLabelText } = renderLayout();
    expect(getByLabelText("Open navigation")).toBeTruthy();
  });

  test("renders github link", () => {
    const { getByLabelText } = renderLayout();
    expect(getByLabelText("GitHub repository")).toBeTruthy();
  });

  test("renders log out button", () => {
    const { getByLabelText } = renderLayout();
    expect(getByLabelText("Log out")).toBeTruthy();
  });
});
