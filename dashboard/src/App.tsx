import { useState, useEffect } from "react";
import { DashboardPage, LibraryPage } from "./pages";

type Page = "dashboard" | "library";

function getPageFromHash(): Page {
  const hash = window.location.hash.slice(1);
  if (hash === "library") return "library";
  return "dashboard";
}

export default function App() {
  const [page, setPage] = useState<Page>(getPageFromHash);

  useEffect(() => {
    const handleHashChange = () => setPage(getPageFromHash());
    window.addEventListener("hashchange", handleHashChange);
    return () => window.removeEventListener("hashchange", handleHashChange);
  }, []);

  if (page === "library") {
    return <LibraryPage />;
  }

  return <DashboardPage />;
}
