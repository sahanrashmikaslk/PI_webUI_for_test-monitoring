import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { CONFIG } from './config.js';
import authRoutes from './routes/authRoutes.js';
import clinicianRoutes from './routes/clinicianRoutes.js';
import parentRoutes from './routes/parentRoutes.js';
import { clinicianAuth, parentAuth } from './middleware/auth.js';

const app = express();

app.use(helmet());
app.use(
  cors({
    origin: true,
    credentials: true
  })
);
app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'parent-backend', timestamp: new Date().toISOString() });
});

app.use('/api', authRoutes);
app.use('/api/clinician', clinicianAuth, clinicianRoutes);
app.use('/api/parent', parentAuth, parentRoutes);

app.use((err, req, res, next) => {
  console.error('Parent backend error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(CONFIG.port, () => {
  console.log(`Parent backend listening on port ${CONFIG.port}`);
});

