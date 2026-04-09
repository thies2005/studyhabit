import jwt from 'jsonwebtoken';
import { prisma } from '../index.js';
import { config } from '../config.js';

export interface UserPayload {
  userId: string;
  email: string;
}

export const authMiddleware = (
  req: any,
  res: any,
  next: any
) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'No token provided' });
    }

    const token = authHeader.substring(7);

    const decoded = jwt.verify(token, config.JWT_SECRET) as UserPayload;
    req.user = decoded;
    next();
  } catch (error) {
    return res.status(401).json({ error: 'Invalid token' });
  }
};
