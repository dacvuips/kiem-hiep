class_name LunarCalendar
extends RefCounted
## Âm lịch Việt Nam (thuật toán Hồ Ngọc Đức, múi giờ +7) — đổi ngày âm -> dương cho sự kiện theo âm lịch (Tết, Trung Thu).
## Thuần tính toán, không phụ thuộc cảnh — dùng chung máy chơi và game server.

const VN_TZ := 7.0

static func _int(d: float) -> int:
	return int(floor(d))

static func jd_from_date(dd: int, mm: int, yy: int) -> int:
	var a := _int((14 - mm) / 12.0)
	var y := yy + 4800 - a
	var m := mm + 12 * a - 3
	var jd := dd + _int((153 * m + 2) / 5.0) + 365 * y + _int(y / 4.0) - _int(y / 100.0) + _int(y / 400.0) - 32045
	if jd < 2299161:
		jd = dd + _int((153 * m + 2) / 5.0) + 365 * y + _int(y / 4.0) - 32083
	return jd

## Ngày Julius -> {year, month, day} dương lịch.
static func jd_to_date(jd: int) -> Dictionary:
	var a: int
	var b: int
	var c: int
	if jd > 2299160:
		a = jd + 32044
		b = _int((4 * a + 3) / 146097.0)
		c = a - _int((b * 146097) / 4.0)
	else:
		b = 0
		c = jd + 32082
	var d := _int((4 * c + 3) / 1461.0)
	var e := c - _int((1461 * d) / 4.0)
	var m := _int((5 * e + 2) / 153.0)
	return {
		"day": e - _int((153 * m + 2) / 5.0) + 1,
		"month": m + 3 - 12 * _int(m / 10.0),
		"year": b * 100 + d - 4800 + _int(m / 10.0),
	}

static func _new_moon(k: int) -> float:
	var t := k / 1236.85
	var t2 := t * t
	var t3 := t2 * t
	var dr := PI / 180.0
	var jd1 := 2415020.75933 + 29.53058868 * k + 0.0001178 * t2 - 0.000000155 * t3
	jd1 += 0.00033 * sin((166.56 + 132.87 * t - 0.009173 * t2) * dr)
	var m := 359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3
	var mpr := 306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3
	var f := 21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3
	var c1 := (0.1734 - 0.000393 * t) * sin(m * dr) + 0.0021 * sin(2 * dr * m)
	c1 = c1 - 0.4068 * sin(mpr * dr) + 0.0161 * sin(dr * 2 * mpr)
	c1 = c1 - 0.0004 * sin(dr * 3 * mpr)
	c1 = c1 + 0.0104 * sin(dr * 2 * f) - 0.0051 * sin(dr * (m + mpr))
	c1 = c1 - 0.0074 * sin(dr * (m - mpr)) + 0.0004 * sin(dr * (2 * f + m))
	c1 = c1 - 0.0004 * sin(dr * (2 * f - m)) - 0.0006 * sin(dr * (2 * f + mpr))
	c1 = c1 + 0.0010 * sin(dr * (2 * f - mpr)) + 0.0005 * sin(dr * (2 * mpr + m))
	var deltat: float
	if t < -11:
		deltat = 0.001 + 0.000839 * t + 0.0002261 * t2 - 0.00000845 * t3 - 0.000000081 * t * t3
	else:
		deltat = -0.000278 + 0.000265 * t + 0.000262 * t2
	return jd1 + c1 - deltat

static func _sun_longitude(jdn: float) -> float:
	var t := (jdn - 2451545.0) / 36525.0
	var t2 := t * t
	var dr := PI / 180.0
	var m := 357.52910 + 35999.05030 * t - 0.0001559 * t2 - 0.00000048 * t * t2
	var l0 := 280.46645 + 36000.76983 * t + 0.0003032 * t2
	var dl := (1.914600 - 0.004817 * t - 0.000014 * t2) * sin(dr * m)
	dl += (0.019993 - 0.000101 * t) * sin(dr * 2 * m) + 0.000290 * sin(dr * 3 * m)
	var l := (l0 + dl) * dr
	return l - PI * 2 * _int(l / (PI * 2))

static func _sun_sector(day_number: int, tz: float) -> int:
	return _int(_sun_longitude(day_number - 0.5 - tz / 24.0) / PI * 6)

static func _new_moon_day(k: int, tz: float) -> int:
	return _int(_new_moon(k) + 0.5 + tz / 24.0)

static func _lunar_month_11(yy: int, tz: float) -> int:
	var off := jd_from_date(31, 12, yy) - 2415021
	var k := _int(off / 29.530588853)
	var nm := _new_moon_day(k, tz)
	if _sun_sector(nm, tz) >= 9:
		nm = _new_moon_day(k - 1, tz)
	return nm

static func _leap_month_offset(a11: int, tz: float) -> int:
	var k := _int((a11 - 2415021.076998695) / 29.530588853 + 0.5)
	var i := 1
	var arc := _sun_sector(_new_moon_day(k + i, tz), tz)
	var last := -1
	while arc != last and i < 14:
		last = arc
		i += 1
		arc = _sun_sector(_new_moon_day(k + i, tz), tz)
	return i - 1

## Ngày âm (ngày, tháng, năm âm, tháng nhuận?) -> {year, month, day} dương lịch; {} nếu tháng nhuận không tồn tại.
static func lunar_to_solar(lunar_day: int, lunar_month: int, lunar_year: int, leap := false, tz := VN_TZ) -> Dictionary:
	var a11: int
	var b11: int
	if lunar_month < 11:
		a11 = _lunar_month_11(lunar_year - 1, tz)
		b11 = _lunar_month_11(lunar_year, tz)
	else:
		a11 = _lunar_month_11(lunar_year, tz)
		b11 = _lunar_month_11(lunar_year + 1, tz)
	var k := _int(0.5 + (a11 - 2415021.076998695) / 29.530588853)
	var off := lunar_month - 11
	if off < 0:
		off += 12
	if b11 - a11 > 365:
		var leap_off := _leap_month_offset(a11, tz)
		var leap_month := leap_off - 2
		if leap_month < 0:
			leap_month += 12
		if leap and lunar_month != leap_month:
			return {}
		elif leap or off >= leap_off:
			off += 1
	var month_start := _new_moon_day(k + off, tz)
	return jd_to_date(month_start + lunar_day - 1)
