import { BrowserRouter, Routes, Route } from "react-router";
import { DashboardLayout } from "@/components/DashboardLayout";
import { DashboardPage } from "@/pages/DashboardPage";

const App = () => (
  <BrowserRouter>
    <Routes>
      <Route element={<DashboardLayout />}>
        <Route path="/" element={<DashboardPage />} />
      </Route>
    </Routes>
  </BrowserRouter>
);

export default App;
