// Copyright 2019 Aleksander Woźniak
// SPDX-License-Identifier: Apache-2.0

part of table_calendar;

typedef DayBuilder = Widget Function(BuildContext context, DateTime day);

typedef FocusedDayBuilder = Widget Function(
    BuildContext context, DateTime day, DateTime focusedMonth);

/// Gestures available to `TableCalendar`.
enum AvailableGestures { none, verticalSwipe, horizontalSwipe, all }

enum CalendarFormat { month, twoWeeks, week }

enum StartingDayOfWeek {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday,
}

int _getWeekdayNumber(StartingDayOfWeek weekday) {
  return StartingDayOfWeek.values.indexOf(weekday) + 1;
}

bool isSameDay(DateTime a, DateTime b) {
  if (a == null || b == null) {
    return false;
  }

  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class TableCalendarBase extends StatefulWidget {
  final DateTime firstDay;
  final DateTime lastDay;
  final DateTime focusedDay;
  final CalendarFormat calendarFormat;
  final DayBuilder dowBuilder;
  final FocusedDayBuilder dayBuilder;
  final double dowHeight;
  final double rowHeight;
  final bool dowVisible;
  final Decoration dowDecoration;
  final Decoration rowDecoration;
  final StartingDayOfWeek startingDayOfWeek;
  final AvailableGestures availableGestures;
  final SimpleSwipeConfig simpleSwipeConfig;
  final Map<CalendarFormat, String> availableCalendarFormats;
  final SwipeCallback onVerticalSwipe;
  final void Function(DateTime focusedDay) onPageChanged;
  final void Function(PageController pageController) onCalendarCreated;

  TableCalendarBase({
    Key key,
    @required this.firstDay,
    @required this.lastDay,
    @required this.focusedDay,
    this.calendarFormat = CalendarFormat.month,
    this.dowBuilder,
    @required this.dayBuilder,
    this.dowHeight,
    @required this.rowHeight,
    this.dowVisible = true,
    this.dowDecoration,
    this.rowDecoration,
    this.startingDayOfWeek = StartingDayOfWeek.sunday,
    this.availableGestures = AvailableGestures.all,
    this.simpleSwipeConfig = const SimpleSwipeConfig(
      verticalThreshold: 25.0,
      swipeDetectionBehavior: SwipeDetectionBehavior.continuousDistinct,
    ),
    this.availableCalendarFormats = const {
      CalendarFormat.month: 'Month',
      CalendarFormat.twoWeeks: '2 weeks',
      CalendarFormat.week: 'Week',
    },
    this.onVerticalSwipe,
    this.onPageChanged,
    this.onCalendarCreated,
  })  : assert(!dowVisible || (dowHeight != null && dowBuilder != null)),
        assert(dayBuilder != null),
        assert(rowHeight != null),
        assert(firstDay != null),
        assert(lastDay != null),
        assert(focusedDay != null),
        assert(isSameDay(focusedDay, firstDay) || focusedDay.isAfter(firstDay)),
        assert(isSameDay(focusedDay, lastDay) || focusedDay.isBefore(lastDay)),
        super(key: key);

  @override
  _TableCalendarBaseState createState() => _TableCalendarBaseState();
}

class _TableCalendarBaseState extends State<TableCalendarBase>
    with SingleTickerProviderStateMixin {
  ValueNotifier<double> _pageHeight;
  PageController _pageController;
  DateTime _focusedDay;
  int _previousIndex;
  bool _pageCallbackDisabled;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.focusedDay;

    final rowCount = _getRowCount(widget.calendarFormat, _focusedDay);
    _pageHeight = ValueNotifier(_getPageHeight(rowCount));

    final initialPage = _calculateFocusedPage(
        widget.calendarFormat, widget.firstDay, _focusedDay);

    _pageController = PageController(initialPage: initialPage);
    widget.onCalendarCreated?.call(_pageController);

    _previousIndex = initialPage;
    _pageCallbackDisabled = false;
  }

  @override
  void didUpdateWidget(TableCalendarBase oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.calendarFormat != oldWidget.calendarFormat) {
      _updatePage();
    }

    if (_focusedDay != widget.focusedDay) {
      _focusedDay = widget.focusedDay;
      _updatePage();
    }

    if (widget.rowHeight != oldWidget.rowHeight ||
        widget.dowHeight != oldWidget.dowHeight) {
      final rowCount = _getRowCount(widget.calendarFormat, _focusedDay);
      _pageHeight.value = _getPageHeight(rowCount);
    }

    if (widget.startingDayOfWeek != oldWidget.startingDayOfWeek) {
      final rowCount = _getRowCount(widget.calendarFormat, _focusedDay);
      _pageHeight.value = _getPageHeight(rowCount);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pageHeight.dispose();
    super.dispose();
  }

  bool get _canScrollHorizontally =>
      widget.availableGestures == AvailableGestures.all ||
      widget.availableGestures == AvailableGestures.horizontalSwipe;

  bool get _canScrollVertically =>
      widget.availableGestures == AvailableGestures.all ||
      widget.availableGestures == AvailableGestures.verticalSwipe;

  void _updatePage() {
    final currentIndex = _calculateFocusedPage(
        widget.calendarFormat, widget.firstDay, _focusedDay);

    final endIndex = _calculateFocusedPage(
        widget.calendarFormat, widget.firstDay, widget.lastDay);

    if (currentIndex != _previousIndex ||
        currentIndex == 0 ||
        currentIndex == endIndex) {
      _pageCallbackDisabled = true;
    }

    _previousIndex = currentIndex;
    final rowCount = _getRowCount(widget.calendarFormat, _focusedDay);
    _pageHeight.value = _getPageHeight(rowCount);

    _pageController.jumpToPage(currentIndex);
    _pageCallbackDisabled = false;
  }

  @override
  Widget build(BuildContext context) {
    return SimpleGestureDetector(
      onVerticalSwipe: _canScrollVertically ? widget.onVerticalSwipe : null,
      swipeConfig: widget.simpleSwipeConfig,
      child: ValueListenableBuilder<double>(
        valueListenable: _pageHeight,
        builder: (context, value, child) {
          return AnimatedSize(
            duration: const Duration(milliseconds: 200),
            vsync: this,
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: _pageHeight.value,
              child: child,
            ),
          );
        },
        child: _CalendarCore(
          pageController: _pageController,
          scrollPhysics: _canScrollHorizontally
              ? PageScrollPhysics()
              : NeverScrollableScrollPhysics(),
          firstDay: widget.firstDay,
          lastDay: widget.lastDay,
          startingDayOfWeek: widget.startingDayOfWeek,
          calendarFormat: widget.calendarFormat,
          previousIndex: _previousIndex,
          focusedDay: _focusedDay,
          dowVisible: widget.dowVisible,
          dowDecoration: widget.dowDecoration,
          rowDecoration: widget.rowDecoration,
          onPageChanged: (index, focusedMonth, rowCount) {
            if (!isSameDay(_focusedDay, focusedMonth)) {
              _focusedDay = focusedMonth;
            }

            if (!_pageCallbackDisabled) {
              _previousIndex = index;
              _pageHeight.value = _getPageHeight(rowCount);

              widget.onPageChanged?.call(focusedMonth);
            }

            _pageCallbackDisabled = false;
          },
          dowBuilder: (context, day) {
            return SizedBox(
              height: widget.dowHeight,
              child: widget.dowBuilder(context, day),
            );
          },
          dayBuilder: (context, day, focusedMonth) {
            return SizedBox(
              height: widget.rowHeight,
              child: widget.dayBuilder(context, day, focusedMonth),
            );
          },
        ),
      ),
    );
  }

  double _getPageHeight(int rowCount) {
    final dowHeight = widget.dowVisible ? widget.dowHeight : 0.0;
    return dowHeight + rowCount * widget.rowHeight;
  }

  int _calculateFocusedPage(
      CalendarFormat format, DateTime startDay, DateTime focusedDay) {
    switch (format) {
      case CalendarFormat.month:
        return _getMonthCount(startDay, focusedDay);
      case CalendarFormat.twoWeeks:
        return _getTwoWeekCount(startDay, focusedDay);
      case CalendarFormat.week:
        return _getWeekCount(startDay, focusedDay);
      default:
        return _getMonthCount(startDay, focusedDay);
    }
  }

  int _getMonthCount(DateTime first, DateTime last) {
    final yearDif = last.year - first.year;
    final monthDif = last.month - first.month;

    return yearDif * 12 + monthDif;
  }

  int _getWeekCount(DateTime first, DateTime last) {
    return last.difference(_firstDayOfWeek(first)).inDays ~/ 7;
  }

  int _getTwoWeekCount(DateTime first, DateTime last) {
    return last.difference(_firstDayOfWeek(first)).inDays ~/ 14;
  }

  int _getRowCount(CalendarFormat format, DateTime focusedDay) {
    if (format == CalendarFormat.twoWeeks) {
      return 2;
    } else if (format == CalendarFormat.week) {
      return 1;
    }

    final first = _firstDayOfMonth(focusedDay);
    final daysBefore = _getDaysBefore(first);
    final firstToDisplay = first.subtract(Duration(days: daysBefore));

    final last = _lastDayOfMonth(focusedDay);
    final daysAfter = _getDaysAfter(last);
    final lastToDisplay = last.add(Duration(days: daysAfter));

    return lastToDisplay.difference(firstToDisplay).inDays ~/ 7;
  }

  int _getDaysBefore(DateTime firstDay) {
    return (firstDay.weekday +
            7 -
            _getWeekdayNumber(widget.startingDayOfWeek)) %
        7;
  }

  int _getDaysAfter(DateTime lastDay) {
    int invertedStartingWeekday =
        8 - _getWeekdayNumber(widget.startingDayOfWeek);

    int daysAfter = 7 - ((lastDay.weekday + invertedStartingWeekday) % 7) + 1;
    if (daysAfter == 8) {
      daysAfter = 1;
    }

    return daysAfter;
  }

  DateTime _firstDayOfWeek(DateTime week) {
    final daysBefore = _getDaysBefore(week);
    return week.subtract(Duration(days: daysBefore));
  }

  DateTime _firstDayOfMonth(DateTime month) {
    return DateTime.utc(month.year, month.month, 1);
  }

  DateTime _lastDayOfMonth(DateTime month) {
    final date = month.month < 12
        ? DateTime.utc(month.year, month.month + 1, 1)
        : DateTime.utc(month.year + 1, 1, 1);
    return date.subtract(const Duration(days: 1));
  }
}
