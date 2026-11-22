import '../../../../core/failures.dart';
import '../entities/announcement.dart';
import '../repositories/announcement_repository.dart';

class GetAnnouncements {
  const GetAnnouncements(this._repository);

  final AnnouncementRepository _repository;

  Future<({List<Announcement> items, Failure? failure})> call({
    int page = 1,
    int limit = 20,
    bool forceRefresh = false,
  }) {
    return _repository.fetchPage(
      page: page,
      limit: limit,
      forceRefresh: forceRefresh,
    );
  }
}
