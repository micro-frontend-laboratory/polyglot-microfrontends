import { NavLink, Outlet } from 'react-router';

export function App() {
  return (
    <>
      <header className="page-header">
        <h1>Insights</h1>
        <p>React. The same two components, used two ways.</p>
        <nav className="page-nav">
          <NavLink to="/components">React components</NavLink>
          <NavLink to="/web-components">Web components</NavLink>
        </nav>
      </header>

      <main>
        <Outlet />
      </main>
    </>
  );
}
