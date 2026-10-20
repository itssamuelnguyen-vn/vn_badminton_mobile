import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'payment_screen.dart';

/// "Lịch cố định": the customer's weekly bookings made by the venue, each month to pay by transfer (CD-10),
/// and the requests sent from the app (CD-09).
class SeriesScreen extends StatefulWidget {
  const SeriesScreen({super.key});

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  List<Series> _series = const [];
  List<SeriesRequest> _requests = const [];
  bool _loaded = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = AppScope.read(context).api;
    try {
      final results = await Future.wait([api.get('/series'), api.get('/series_requests')]);
      if (!mounted) return;
      setState(() {
        _series = [for (final one in results[0]['series'] as List) Series.fromJson(one)];
        _requests = [for (final one in results[1]['requests'] as List) SeriesRequest.fromJson(one)];
        _loaded = true;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _pay(Series series, SeriesMonth month) async {
    final s = S.of(context);
    try {
      final json = await AppScope.read(context).api.post('/series/${series.id}/pay', {'month': month.month});
      if (!mounted) return;
      final payment = Payment.fromJson(json);
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PaymentScreen(token: payment.token, initial: payment)),
      );
      _load();
    } catch (error) {
      if (mounted) showMessage(context, s.error(error));
    }
  }

  Future<void> _withdraw(SeriesRequest request) async {
    final s = S.of(context);
    try {
      await AppScope.read(context).api.delete('/series_requests/${request.id}');
      _load();
    } catch (error) {
      if (mounted) showMessage(context, s.error(error));
    }
  }

  Future<void> _newRequest() async {
    final sent = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const SeriesRequestScreen()));
    if (sent == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.lime,
        foregroundColor: AppColors.ink,
        icon: const Icon(Icons.add_rounded),
        label: Text(s.newRequest, style: const TextStyle(fontWeight: FontWeight.w700)),
        onPressed: _newRequest,
      ),
      body: Column(
        children: [
          GradientHeader(title: s.regularBookings, subtitle: s.regularIntro),
          Expanded(
            child: !_loaded
                ? (_error != null
                      ? ErrorView(message: s.error(_error!), onRetry: _load)
                      : const Center(child: CircularProgressIndicator()))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      children: [
                        if (_series.isEmpty && _requests.isEmpty)
                          EmptyState(icon: Icons.repeat_rounded, text: s.regularIntro),
                        if (_series.isNotEmpty) SectionTitle(s.mySeries),
                        for (final series in _series) _seriesCard(s, series),
                        if (_requests.isNotEmpty) SectionTitle(s.myRequests),
                        for (final request in _requests) _requestCard(s, request),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _schedule(S s, List<String> courts, List<int> days, int start, int end) =>
      '${courts.join(', ')} · ${days.map(s.weekday).join(', ')} · ${minuteLabel(start)}–${minuteLabel(end)}';

  Widget _seriesCard(S s, Series series) => SoftCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const IconBadge(Icons.repeat_rounded, AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _schedule(s, series.courts, series.daysOfWeek, series.startMinute, series.endMinute),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${isoDateLabel(series.startsOn)} – ${isoDateLabel(series.endsOn)}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Divider(height: 24),
        for (final month in series.months)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.monthLabel(month.month), style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(s.sessionsCount(month.sessions), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                    ],
                  ),
                ),
                if (month.paid)
                  StatusPill(s.monthPaid, AppColors.primary, icon: Icons.check_rounded)
                else if (month.dueVnd > 0)
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      backgroundColor: AppColors.orange,
                    ),
                    onPressed: () => _pay(series, month),
                    child: Text(s.payMonth(vnd(month.dueVnd))),
                  ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _requestCard(S s, SeriesRequest request) {
    final color = switch (request.status) {
      'approved' => AppColors.primary,
      'declined' => AppColors.rose,
      'pending' => AppColors.amber,
      _ => AppColors.muted,
    };
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _schedule(s, request.courts, request.daysOfWeek, request.startMinute, request.endMinute),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              StatusPill(s.requestStatus(request.status), color),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${isoDateLabel(request.startsOn)} – ${isoDateLabel(request.endsOn)}',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          if ((request.declineReason ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(s.reason(request.declineReason!), style: const TextStyle(color: AppColors.rose)),
            ),
          if (request.status == 'pending')
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => _withdraw(request), child: Text(s.withdraw)),
            ),
        ],
      ),
    );
  }
}

/// The form of a weekly booking request: courts, days, times, dates and a note.
class SeriesRequestScreen extends StatefulWidget {
  const SeriesRequestScreen({super.key});

  @override
  State<SeriesRequestScreen> createState() => _SeriesRequestScreenState();
}

class _SeriesRequestScreenState extends State<SeriesRequestScreen> {
  final _note = TextEditingController();
  final Set<int> _courts = {};
  final Set<int> _days = {};
  int _start = 18 * 60;
  int _end = 20 * 60;
  late DateTime _from = DateTime.now().add(const Duration(days: 1));
  late DateTime _to = _from.add(const Duration(days: 56));
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool from) async {
    final first = DateTime.now().add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: from ? first : _from,
      lastDate: _from.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked;
      }
    });
  }

  Future<void> _submit() async {
    final s = S.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.read(context).api.post('/series_requests', {
        'court_ids': _courts.toList(),
        'days_of_week': _days.toList()..sort(),
        'start_minute': _start,
        'end_minute': _end,
        'starts_on': DateFormat('yyyy-MM-dd').format(_from),
        'ends_on': DateFormat('yyyy-MM-dd').format(_to),
        'note': _note.text.trim(),
      });
      if (!mounted) return;
      showMessage(context, s.requestSent);
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = s.error(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final courts = AppScope.of(context).venue?.courts ?? const <Court>[];
    final minutes = [for (var m = 5 * 60; m <= 23 * 60; m += 30) m];
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHeader(title: s.newRequest, subtitle: s.regularIntro),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                label(s.courts),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final court in courts)
                      FilterChip(
                        label: Text(court.name),
                        selected: _courts.contains(court.id),
                        selectedColor: AppColors.mint,
                        onSelected: (on) => setState(() => on ? _courts.add(court.id) : _courts.remove(court.id)),
                      ),
                  ],
                ),
                label(s.daysOfWeek),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final day in [1, 2, 3, 4, 5, 6, 0])
                      FilterChip(
                        label: Text(s.weekday(day)),
                        selected: _days.contains(day),
                        selectedColor: AppColors.mint,
                        onSelected: (on) => setState(() => on ? _days.add(day) : _days.remove(day)),
                      ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          label(s.startTime),
                          DropdownButtonFormField<int>(
                            initialValue: _start,
                            items: [
                              for (final m in minutes) DropdownMenuItem(value: m, child: Text(minuteLabel(m))),
                            ],
                            onChanged: (m) => setState(() {
                              _start = m!;
                              if (_end <= _start) _end = _start + 60;
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          label(s.endTime),
                          DropdownButtonFormField<int>(
                            key: ValueKey(_start),
                            initialValue: _end,
                            items: [
                              for (final m in [...minutes.where((m) => m > _start), 24 * 60])
                                DropdownMenuItem(value: m, child: Text(minuteLabel(m))),
                            ],
                            onChanged: (m) => setState(() => _end = m!),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          label(s.fromDate),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.event_rounded),
                            label: Text(DateFormat('dd/MM/yyyy').format(_from)),
                            onPressed: () => _pickDate(true),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          label(s.toDate),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.event_rounded),
                            label: Text(DateFormat('dd/MM/yyyy').format(_to)),
                            onPressed: () => _pickDate(false),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _note,
                  maxLength: 500,
                  maxLines: 2,
                  decoration: InputDecoration(labelText: s.note, prefixIcon: const Icon(Icons.edit_note_rounded)),
                ),
                if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.rose)),
                const SizedBox(height: 16),
                GradientButton(
                  label: s.newRequest,
                  icon: Icons.send_rounded,
                  busy: _busy,
                  onPressed: _courts.isEmpty || _days.isEmpty ? null : _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
