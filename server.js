const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

const bots = {};

app.use(express.json());
app.use((_, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  next();
});
app.options('*', (_, res) => res.sendStatus(204));

app.post('/api/update', (req, res) => {
  const data = req.body;
  const botId = data.bot_id || 'bot_default';
  bots[botId] = { ...data, last_seen: Date.now() };
  res.json({ status: 'ok' });
});

app.get('/api/status', (_, res) => res.json(bots));

app.listen(PORT, () => console.log('GT Monitor on port ' + PORT));
