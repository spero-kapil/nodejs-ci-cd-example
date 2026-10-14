// Import the Express module
const express = require('express');

// Initialize the Express application
const app = express();

// Define the port number
const PORT = 3000;

// Handle GET requests to the root URL ("/")
app.get('/', (req, res) => {
  res.send('Hello, World! Your Node.js app is running......STAGING!!');
});

// Start the server and listen for connections
app.listen(PORT, () => {
  console.log(`Server is running at http://localhost:${PORT}`);
});
