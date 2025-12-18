import { useState, useEffect } from 'react'

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:3001'

function App() {
  const [instruction, setInstruction] = useState(null)
  const [error, setError] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetch(`${API_BASE_URL}/api/instruction`)
      .then((response) => {
        if (!response.ok) {
          throw new Error('Erreur lors de la récupération des consignes')
        }
        return response.json()
      })
      .then((data) => {
        setInstruction(data)
        setLoading(false)
      })
      .catch((err) => {
        setError(err.message)
        setLoading(false)
      })
  }, [])

  return (
    <div className="container">
      <h1>Consignes</h1>
      {loading && <p>Chargement...</p>}
      {error && <p className="error">Erreur : {error}</p>}
      {instruction && (
        <div className="instruction">
          <p>{instruction.message}</p>
        </div>
      )}
    </div>
  )
}

export default App
