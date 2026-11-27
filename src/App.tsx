import { BrowserRouter, Route, Routes } from 'react-router-dom'
import { Layout } from './components/Layout'
import { Heute } from './pages/Heute'
import { Veranstaltungen, Technik, Leute, NichtGefunden } from './pages/Platzhalter'
import { Status } from './pages/Status'

export function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route element={<Layout />}>
          <Route index element={<Heute />} />
          <Route path="veranstaltungen" element={<Veranstaltungen />} />
          <Route path="technik" element={<Technik />} />
          <Route path="leute" element={<Leute />} />
          <Route path="status" element={<Status />} />
          <Route path="*" element={<NichtGefunden />} />
        </Route>
      </Routes>
    </BrowserRouter>
  )
}
