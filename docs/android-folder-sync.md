# Android folder sync

Update StudyHabit on every device before turning on folder sync. If you used folder sync before, keep a separate export from each device and keep the existing `studyhabit_sync.json` and `studyhabit_sync.bak.json` files.

1. Open **Settings → Cloud Sync & Account → Folder Sync**.
2. On each device, select the same writable shared folder in the Android folder picker. If Google Drive does not offer a folder in the picker, the app cannot use it directly. A folder mirrored to the same Drive location on every device can work if the mirroring app transfers new files in both directions. Two local folders with the same name do not share data by themselves.
3. Tap **Sync Folder Now** on the first device. Once the folder provider shows the new file on the second device, tap **Sync Folder Now** there. Use the project switcher if records were imported into a different project.

StudyHabit merges records from the files visible to Android. Each device publishes a new snapshot without replacing another device’s file. Changes to different records merge; if both devices change the same record before syncing, one version wins. Deletions are carried as records so older snapshots cannot restore a deleted item. The old shared file and its backup are migration inputs. Older StudyHabit builds cannot read the new publications.

StudyHabit checks on open and after edits and asks Android to retry and check periodically when connected. Android and the folder provider control when background work runs and when another device can see new files. A completed folder check does not confirm that Drive has uploaded the file or that another device received it.

Published snapshots are kept for recovery. Keep them together; do not delete snapshots from an active folder. Files can accumulate as data changes. PDF entries carry their metadata, but the PDF must still be accessible or relinked on each device. For a manual transfer, use **Save File…** on one device and **Merge File…** on the other.
