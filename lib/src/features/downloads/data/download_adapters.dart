import 'package:hive/hive.dart';

import 'download_models.dart';

class DownloadedContentAdapter extends TypeAdapter<DownloadedContent> {
  @override
  final int typeId = 10;

  @override
  DownloadedContent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DownloadedContent(
      id: fields[0] as String,
      contentId: fields[1] as String,
      title: fields[2] as String,
      posterUrl: fields[3] as String,
      description: fields[4] as String,
      serverName: fields[5] as String,
      serverType: fields[6] as String,
      ftpServerId: fields[7] as String,
      contentType: fields[8] as String,
      videoUrl: fields[9] as String,
      localPath: fields[10] as String,
      fileSize: fields[11] as int,
      downloadedAt: fields[12] as DateTime,
      year: fields[13] as String?,
      quality: fields[14] as String?,
      rating: fields[15] as double?,
      seasonNumber: fields[16] as int?,
      episodeNumber: fields[17] as int?,
      episodeTitle: fields[18] as String?,
      seriesTitle: fields[19] as String?,
      totalSeasons: fields[20] as int?,
      metadata: (fields[21] as Map?)?.cast<String, dynamic>(),
      localPosterPath: fields[22] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, DownloadedContent obj) {
    writer
      ..writeByte(23)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.contentId)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.posterUrl)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.serverName)
      ..writeByte(6)
      ..write(obj.serverType)
      ..writeByte(7)
      ..write(obj.ftpServerId)
      ..writeByte(8)
      ..write(obj.contentType)
      ..writeByte(9)
      ..write(obj.videoUrl)
      ..writeByte(10)
      ..write(obj.localPath)
      ..writeByte(11)
      ..write(obj.fileSize)
      ..writeByte(12)
      ..write(obj.downloadedAt)
      ..writeByte(13)
      ..write(obj.year)
      ..writeByte(14)
      ..write(obj.quality)
      ..writeByte(15)
      ..write(obj.rating)
      ..writeByte(16)
      ..write(obj.seasonNumber)
      ..writeByte(17)
      ..write(obj.episodeNumber)
      ..writeByte(18)
      ..write(obj.episodeTitle)
      ..writeByte(19)
      ..write(obj.seriesTitle)
      ..writeByte(20)
      ..write(obj.totalSeasons)
      ..writeByte(21)
      ..write(obj.metadata)
      ..writeByte(22)
      ..write(obj.localPosterPath);
  }
}

class DownloadStatusAdapter extends TypeAdapter<DownloadStatus> {
  @override
  final int typeId = 12;

  @override
  DownloadStatus read(BinaryReader reader) {
    return DownloadStatus.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, DownloadStatus obj) {
    writer.writeByte(obj.index);
  }
}

class DownloadTaskAdapter extends TypeAdapter<DownloadTask> {
  @override
  final int typeId = 11;

  @override
  DownloadTask read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DownloadTask(
      id: fields[0] as String,
      contentId: fields[1] as String,
      title: fields[2] as String,
      posterUrl: fields[3] as String,
      description: fields[4] as String,
      serverName: fields[5] as String,
      serverType: fields[6] as String,
      ftpServerId: fields[7] as String,
      contentType: fields[8] as String,
      videoUrl: fields[9] as String,
      status: fields[10] as DownloadStatus,
      progress: fields[11] as double,
      downloadedBytes: fields[12] as int,
      totalBytes: fields[13] as int,
      createdAt: fields[14] as DateTime,
      year: fields[15] as String?,
      quality: fields[16] as String?,
      rating: fields[17] as double?,
      seasonNumber: fields[18] as int?,
      episodeNumber: fields[19] as int?,
      episodeTitle: fields[20] as String?,
      seriesTitle: fields[21] as String?,
      totalSeasons: fields[22] as int?,
      metadata: (fields[23] as Map?)?.cast<String, dynamic>(),
      taskId: fields[24] as String?,
      localPath: fields[25] as String?,
      speed: fields[26] as double?,
      eta: fields[27] as int?,
      error: fields[28] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, DownloadTask obj) {
    writer
      ..writeByte(29)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.contentId)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.posterUrl)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.serverName)
      ..writeByte(6)
      ..write(obj.serverType)
      ..writeByte(7)
      ..write(obj.ftpServerId)
      ..writeByte(8)
      ..write(obj.contentType)
      ..writeByte(9)
      ..write(obj.videoUrl)
      ..writeByte(10)
      ..write(obj.status)
      ..writeByte(11)
      ..write(obj.progress)
      ..writeByte(12)
      ..write(obj.downloadedBytes)
      ..writeByte(13)
      ..write(obj.totalBytes)
      ..writeByte(14)
      ..write(obj.createdAt)
      ..writeByte(15)
      ..write(obj.year)
      ..writeByte(16)
      ..write(obj.quality)
      ..writeByte(17)
      ..write(obj.rating)
      ..writeByte(18)
      ..write(obj.seasonNumber)
      ..writeByte(19)
      ..write(obj.episodeNumber)
      ..writeByte(20)
      ..write(obj.episodeTitle)
      ..writeByte(21)
      ..write(obj.seriesTitle)
      ..writeByte(22)
      ..write(obj.totalSeasons)
      ..writeByte(23)
      ..write(obj.metadata)
      ..writeByte(24)
      ..write(obj.taskId)
      ..writeByte(25)
      ..write(obj.localPath)
      ..writeByte(26)
      ..write(obj.speed)
      ..writeByte(27)
      ..write(obj.eta)
      ..writeByte(28)
      ..write(obj.error);
  }
}
