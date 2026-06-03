import { PrismaClient } from '@prisma/client';
import { SyncService } from './services/syncService.js';
import crypto from 'crypto';

const prisma = new PrismaClient();

async function main() {
  // 1. Create a dummy user and project/subject
  const userId = 'test-user-' + crypto.randomUUID();
  
  const projectId = crypto.randomUUID();
  const subjectId = crypto.randomUUID();
  const sessionId = crypto.randomUUID();

  console.log('Creating project and subject...');
  
  await prisma.project.create({
    data: {
      id: projectId,
      userId,
      name: 'Test Project',
      colorValue: 0,
    }
  });

  await prisma.subject.create({
    data: {
      id: subjectId,
      projectId,
      name: 'Test Subject',
      colorValue: 0,
      hierarchyMode: 'flat',
      completenessMode: 'none',
    }
  });

  console.log('Pushing a session...');
  
  const pushPayload = {
    sessions: [
      {
        id: sessionId,
        subjectId,
        startedAt: new Date(Date.now() - 3600000).toISOString(), // 1 hour ago
        plannedDurationMinutes: 25,
        actualDurationMinutes: 25,
        pomodorosCompleted: 1,
        isFreeTimer: false,
        xpEarned: 50,
        isDeleted: false,
        updatedAt: new Date(Date.now() - 3600000).toISOString(), // 1 hour ago (offline)
      }
    ]
  };

  const pushResult = await SyncService.pushChanges(userId, pushPayload as any);
  console.log('Push Result:', pushResult);

  console.log('Pulling with since = 2 hours ago...');
  const pullResult = await SyncService.fullPull(userId, new Date(Date.now() - 7200000).toISOString());
  console.log('Pull Result (sessions):', pullResult.sessions);

  console.log('Pulling with since = 5 seconds ago (simulating other device just after push)...');
  const pullResult2 = await SyncService.fullPull(userId, new Date(Date.now() - 5000).toISOString());
  console.log('Pull Result 2 (sessions):', pullResult2.sessions);
  
}

main().catch(e => console.error(e)).finally(() => prisma.$disconnect());
