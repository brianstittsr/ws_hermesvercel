export default async function handler(req, res) {
  const backendUrl = process.env.HERMES_BACKEND_URL;
  
  if (!backendUrl) {
    return res.status(500).json({ error: 'Backend URL not configured' });
  }
  
  try {
    const response = await fetch(`${backendUrl}/api/dashboard/theme`, {
      method: req.method,
      headers: {
        'Content-Type': 'application/json',
        ...req.headers,
      },
      body: req.method !== 'GET' ? JSON.stringify(req.body) : undefined,
    });
    
    const data = await response.json();
    res.status(response.status).json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
}
