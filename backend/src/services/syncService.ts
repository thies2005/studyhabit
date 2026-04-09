export class SyncService {
  static async upsertWithConflictResolution(
    model: any,
    where: any,
    data: any
  ): Promise<any> {
    const existing = await model.findUnique({ where });

    if (!existing || data.updatedAt > existing.updatedAt) {
      return model.upsert({ where, create: data, update: data });
    }

    return existing;
  }
}
