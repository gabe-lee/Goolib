//! //TODO Documentation
//! #### License: Zlib

// zlib license
//
// Copyright (c) 2025, Gabriel Lee Anderson <gla.ander@gmail.com>
//
// This software is provided 'as-is', without any express or implied
// warranty. In no event will the authors be held liable for any damages
// arising from the use of this software.
//
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely, subject to the following restrictions:
//
// 1. The origin of this software must not be misrepresented; you must not
//    claim that you wrote the original software. If you use this software
//    in a product, an acknowledgment in the product documentation would be
//    appreciated but is not required.
// 2. Altered source versions must be plainly marked as such, and must not be
//    misrepresented as being the original software.
// 3. This notice may not be removed or altered from any source distribution.

const std = @import("std");

const Root = @import("./_root.zig");
const Comp = Root.Composition;
const CompChain = Comp.FieldAccessChain;
const Assert = Root.Assert;
const assert_with_reason = Assert.assert_with_reason;

// zig fmt: off
pub const NS_PER_US         =                  1_000;
pub const NS_PER_MS         =              1_000_000;
pub const NS_PER_SEC        =          1_000_000_000;
pub const NS_PER_MIN        =         60_000_000_000;
pub const NS_PER_HOUR       =      3_600_000_000_000;
pub const NS_PER_DAY        =     86_400_000_000_000;
pub const NS_PER_WEEK       =    604_800_000_000_000;
pub const NS_PER_MONTH      =  2_592_000_000_000_000;
pub const NS_PER_MONTH_AVG  =  2_629_743_831_225_000;
pub const NS_PER_YEAR       = 31_536_000_000_000_000;
pub const NS_PER_YEAR_EXACT = 31_556_925_974_700_000;

pub const US_PER_MS         =              1_000;
pub const US_PER_SEC        =          1_000_000;
pub const US_PER_MIN        =         60_000_000;
pub const US_PER_HOUR       =      3_600_000_000;
pub const US_PER_DAY        =     86_400_000_000;
pub const US_PER_WEEK       =    604_800_000_000;
pub const US_PER_MONTH      =  2_592_000_000_000;
pub const US_PER_MONTH_AVG  =  2_629_743_831_225;
pub const US_PER_YEAR       = 31_536_000_000_000;
pub const US_PER_YEAR_EXACT = 31_556_925_974_700;

pub const MS_PER_SEC        =          1_000;
pub const MS_PER_MIN        =         60_000;
pub const MS_PER_HOUR       =      3_600_000;
pub const MS_PER_DAY        =     86_400_000;
pub const MS_PER_WEEK       =    604_800_000;
pub const MS_PER_MONTH      =  2_592_000_000;
pub const MS_PER_MONTH_AVG  =  2_629_743_831;
pub const MS_PER_YEAR       = 31_536_000_000;
pub const MS_PER_YEAR_EXACT = 31_556_925_975;

pub const SEC_PER_MIN        =         60;
pub const SEC_PER_HOUR       =      3_600;
pub const SEC_PER_DAY        =     86_400;
pub const SEC_PER_WEEK       =    604_800;
pub const SEC_PER_MONTH      =  2_592_000;
pub const SEC_PER_MONTH_AVG  =  2_629_744;
pub const SEC_PER_YEAR       = 31_536_000;
pub const SEC_PER_YEAR_EXACT = 31_556_926;

pub const MIN_PER_HOUR       =      60;
pub const MIN_PER_DAY        =   1_440;
pub const MIN_PER_WEEK       =  10_080;
pub const MIN_PER_MONTH      =  43_200;
pub const MIN_PER_MONTH_AVG  =  43_829;
pub const MIN_PER_YEAR       = 525_600;
pub const MIN_PER_YEAR_EXACT = 525_949;

pub const HOUR_PER_DAY        =   24;
pub const HOUR_PER_WEEK       =  168;
pub const HOUR_PER_MONTH      =  720;
pub const HOUR_PER_MONTH_AVG  =  730;
pub const HOUR_PER_YEAR       = 8760;
pub const HOUR_PER_YEAR_EXACT = 8766;

pub const DAY_PER_WEEK  =   7;
pub const DAY_PER_MONTH =  30;
pub const DAY_PER_YEAR  = 365;

pub const WEEK_PER_MONTH =  4;
pub const WEEK_PER_YEAR  = 52;

pub const MONTH_PER_YEAR  = 12;
// zig fmt: on

pub const Years = extern struct {
    val: i64 = 0,

    pub inline fn new(val: i64) Years {
        return Years{ .val = val };
    }

    pub inline fn to_months(self: Years) Months {
        return Months{ .val = self.val * MONTH_PER_YEAR };
    }
    pub inline fn to_weeks(self: Years) Weeks {
        return Weeks{ .val = self.val * WEEK_PER_YEAR };
    }
    pub inline fn to_days(self: Years) Days {
        return Days{ .val = self.val * DAY_PER_YEAR };
    }
    pub inline fn to_hours(self: Years) Hours {
        return Hours{ .val = self.val * HOUR_PER_YEAR_EXACT };
    }
    pub inline fn to_mins(self: Years) Mins {
        return Mins{ .val = self.val * MIN_PER_YEAR_EXACT };
    }
    pub inline fn to_secs(self: Years) Secs {
        return Secs{ .val = self.val * SEC_PER_YEAR_EXACT };
    }
    pub inline fn to_msecs(self: Years) MSecs {
        return MSecs{ .val = self.val * MS_PER_YEAR_EXACT };
    }
    pub inline fn to_usecs(self: Years) USecs {
        return USecs{ .val = self.val * US_PER_YEAR_EXACT };
    }
    pub inline fn to_nsecs(self: Years) NSecs {
        return NSecs{ .val = self.val * NS_PER_YEAR_EXACT };
    }

    pub fn CompProvider(comptime access_years_i64: CompChain) type {
        const Self = access_years_i64.container;
        return struct {
            pub inline fn to_months(self: Self) Months {
                return Months{ .val = access_years_i64.get_from(self) * MONTH_PER_YEAR };
            }
            pub inline fn to_weeks(self: Self) Weeks {
                return Weeks{ .val = access_years_i64.get_from(self) * WEEK_PER_YEAR };
            }
            pub inline fn to_days(self: Self) Days {
                return Days{ .val = access_years_i64.get_from(self) * DAY_PER_YEAR };
            }
            pub inline fn to_hours(self: Self) Hours {
                return Hours{ .val = access_years_i64.get_from(self) * HOUR_PER_YEAR_EXACT };
            }
            pub inline fn to_mins(self: Self) Mins {
                return Mins{ .val = access_years_i64.get_from(self) * MIN_PER_YEAR_EXACT };
            }
            pub inline fn to_secs(self: Self) Secs {
                return Secs{ .val = access_years_i64.get_from(self) * SEC_PER_YEAR_EXACT };
            }
            pub inline fn to_msecs(self: Self) MSecs {
                return MSecs{ .val = access_years_i64.get_from(self) * MS_PER_YEAR_EXACT };
            }
            pub inline fn to_usecs(self: Self) USecs {
                return USecs{ .val = access_years_i64.get_from(self) * US_PER_YEAR_EXACT };
            }
            pub inline fn to_nsecs(self: Self) NSecs {
                return NSecs{ .val = access_years_i64.get_from(self) * NS_PER_YEAR_EXACT };
            }
        };
    }
};
pub const Months = extern struct {
    val: i64 = 0,

    pub inline fn new(val: i64) Months {
        return Months{ .val = val };
    }

    pub inline fn to_years(self: Months) Years {
        return Years{ .val = self.val / MONTH_PER_YEAR };
    }
    pub inline fn to_weeks(self: Months) Weeks {
        return Weeks{ .val = self.val * WEEK_PER_MONTH };
    }
    pub inline fn to_days(self: Months) Days {
        return Days{ .val = self.val * DAY_PER_MONTH };
    }
    pub inline fn to_hours(self: Months) Hours {
        return Hours{ .val = self.val * HOUR_PER_MONTH_AVG };
    }
    pub inline fn to_mins(self: Months) Mins {
        return Mins{ .val = self.val * MIN_PER_MONTH_AVG };
    }
    pub inline fn to_secs(self: Months) Secs {
        return Secs{ .val = self.val * SEC_PER_MONTH_AVG };
    }
    pub inline fn to_msecs(self: Months) MSecs {
        return MSecs{ .val = self.val * MS_PER_MONTH_AVG };
    }
    pub inline fn to_usecs(self: Months) USecs {
        return USecs{ .val = self.val * US_PER_MONTH_AVG };
    }
    pub inline fn to_nsecs(self: Months) NSecs {
        return NSecs{ .val = self.val * NS_PER_MONTH_AVG };
    }
};
pub const Weeks = extern struct {
    val: i64 = 0,

    pub inline fn new(val: i64) Weeks {
        return Weeks{ .val = val };
    }

    pub inline fn to_years(self: Weeks) Years {
        return Years{ .val = self.val / WEEK_PER_YEAR };
    }
    pub inline fn to_months(self: Weeks) Months {
        return Months{ .val = self.val / WEEK_PER_MONTH };
    }
    pub inline fn to_days(self: Weeks) Days {
        return Days{ .val = self.val * DAY_PER_WEEK };
    }
    pub inline fn to_hours(self: Weeks) Hours {
        return Hours{ .val = self.val * HOUR_PER_WEEK };
    }
    pub inline fn to_mins(self: Weeks) Mins {
        return Mins{ .val = self.val * MIN_PER_WEEK };
    }
    pub inline fn to_secs(self: Weeks) Secs {
        return Secs{ .val = self.val * SEC_PER_WEEK };
    }
    pub inline fn to_msecs(self: Weeks) MSecs {
        return MSecs{ .val = self.val * MS_PER_WEEK };
    }
    pub inline fn to_usecs(self: Weeks) USecs {
        return USecs{ .val = self.val * US_PER_WEEK };
    }
    pub inline fn to_nsecs(self: Weeks) NSecs {
        return NSecs{ .val = self.val * NS_PER_WEEK };
    }
};
pub const Days = extern struct {
    val: i64 = 0,

    pub inline fn new(val: i64) Days {
        return Days{ .val = val };
    }

    pub inline fn add(self: Days, t: Days) Days {
        return Days{ .val = self.val + t.val };
    }
    pub inline fn sub(self: Days, t: Days) Days {
        return Days{ .val = self.val - t.val };
    }
    pub inline fn mult(self: Days, t: Days) Days {
        return Days{ .val = self.val * t.val };
    }
    pub inline fn div(self: Days, t: Days) Days {
        return Days{ .val = self.val / t.val };
    }

    pub inline fn to_years(self: Days) Years {
        return Years{ .val = self.val / DAY_PER_YEAR };
    }
    pub inline fn to_months(self: Days) Months {
        return Months{ .val = self.val / DAY_PER_MONTH };
    }
    pub inline fn to_weeks(self: Days) Weeks {
        return Weeks{ .val = self.val / DAY_PER_WEEK };
    }
    pub inline fn to_hours(self: Days) Hours {
        return Hours{ .val = self.val * HOUR_PER_DAY };
    }
    pub inline fn to_mins(self: Days) Mins {
        return Mins{ .val = self.val * MIN_PER_DAY };
    }
    pub inline fn to_secs(self: Days) Secs {
        return Secs{ .val = self.val * SEC_PER_DAY };
    }
    pub inline fn to_msecs(self: Days) MSecs {
        return MSecs{ .val = self.val * MS_PER_DAY };
    }
    pub inline fn to_usecs(self: Days) USecs {
        return USecs{ .val = self.val * US_PER_DAY };
    }
    pub inline fn to_nsecs(self: Days) NSecs {
        return NSecs{ .val = self.val * NS_PER_DAY };
    }
};
pub const Hours = extern struct {
    val: i64 = 0,

    pub inline fn new(val: i64) Hours {
        return Hours{ .val = val };
    }

    pub inline fn add(self: Hours, t: Hours) Hours {
        return Hours{ .val = self.val + t.val };
    }
    pub inline fn sub(self: Hours, t: Hours) Hours {
        return Hours{ .val = self.val - t.val };
    }
    pub inline fn mult(self: Hours, t: Hours) Hours {
        return Hours{ .val = self.val * t.val };
    }
    pub inline fn div(self: Hours, t: Hours) Hours {
        return Hours{ .val = self.val / t.val };
    }

    pub inline fn to_years(self: Hours) Years {
        return Years{ .val = self.val / HOUR_PER_YEAR_EXACT };
    }
    pub inline fn to_months(self: Hours) Months {
        return Months{ .val = self.val / HOUR_PER_MONTH_AVG };
    }
    pub inline fn to_weeks(self: Hours) Weeks {
        return Weeks{ .val = self.val / HOUR_PER_WEEK };
    }
    pub inline fn to_days(self: Hours) Days {
        return Days{ .val = self.val / HOUR_PER_DAY };
    }
    pub inline fn to_mins(self: Hours) Mins {
        return Mins{ .val = self.val * MIN_PER_HOUR };
    }
    pub inline fn to_secs(self: Hours) Secs {
        return Secs{ .val = self.val * SEC_PER_HOUR };
    }
    pub inline fn to_msecs(self: Hours) MSecs {
        return MSecs{ .val = self.val * MS_PER_HOUR };
    }
    pub inline fn to_usecs(self: Hours) USecs {
        return USecs{ .val = self.val * US_PER_HOUR };
    }
    pub inline fn to_nsecs(self: Hours) NSecs {
        return NSecs{ .val = self.val * NS_PER_HOUR };
    }
};
pub const Mins = extern struct {
    val: i64 = 0,

    pub inline fn new(val: i64) Mins {
        return Mins{ .val = val };
    }

    pub inline fn add(self: Mins, t: Mins) Mins {
        return Mins{ .val = self.val + t.val };
    }
    pub inline fn sub(self: Mins, t: Mins) Mins {
        return Mins{ .val = self.val - t.val };
    }
    pub inline fn mult(self: Mins, t: Mins) Mins {
        return Mins{ .val = self.val * t.val };
    }
    pub inline fn div(self: Mins, t: Mins) Mins {
        return Mins{ .val = self.val / t.val };
    }

    pub inline fn to_years(self: Mins) Years {
        return Years{ .val = self.val / MIN_PER_YEAR_EXACT };
    }
    pub inline fn to_months(self: Mins) Months {
        return Months{ .val = self.val / MIN_PER_MONTH_AVG };
    }
    pub inline fn to_weeks(self: Mins) Weeks {
        return Weeks{ .val = self.val / MIN_PER_WEEK };
    }
    pub inline fn to_days(self: Mins) Days {
        return Days{ .val = self.val / MIN_PER_DAY };
    }
    pub inline fn to_hours(self: Mins) Hours {
        return Hours{ .val = self.val / MIN_PER_HOUR };
    }
    pub inline fn to_secs(self: Mins) Secs {
        return Secs{ .val = self.val * SEC_PER_MIN };
    }
    pub inline fn to_msecs(self: Mins) MSecs {
        return MSecs{ .val = self.val * MS_PER_MIN };
    }
    pub inline fn to_usecs(self: Mins) USecs {
        return USecs{ .val = self.val * US_PER_MIN };
    }
    pub inline fn to_nsecs(self: Mins) NSecs {
        return NSecs{ .val = self.val * NS_PER_MIN };
    }
};
pub const Secs = extern struct {
    val: i64 = 0,

    pub inline fn new(val: i64) Secs {
        return Secs{ .val = val };
    }

    pub inline fn now() Secs {
        return Secs{ .val = std.time.timestamp() };
    }

    pub inline fn add(self: Secs, t: Secs) Secs {
        return Secs{ .val = self.val + t.val };
    }
    pub inline fn sub(self: Secs, t: Secs) Secs {
        return Secs{ .val = self.val - t.val };
    }
    pub inline fn mult(self: Secs, t: Secs) Secs {
        return Secs{ .val = self.val * t.val };
    }
    pub inline fn div(self: Secs, t: Secs) Secs {
        return Secs{ .val = self.val / t.val };
    }

    pub inline fn to_years(self: Secs) Years {
        return Years{ .val = self.val / SEC_PER_YEAR_EXACT };
    }
    pub inline fn to_months(self: Secs) Months {
        return Months{ .val = self.val / SEC_PER_MONTH_AVG };
    }
    pub inline fn to_weeks(self: Secs) Weeks {
        return Weeks{ .val = self.val / SEC_PER_WEEK };
    }
    pub inline fn to_days(self: Secs) Days {
        return Days{ .val = self.val / SEC_PER_DAY };
    }
    pub inline fn to_hours(self: Secs) Hours {
        return Hours{ .val = self.val / SEC_PER_HOUR };
    }
    pub inline fn to_mins(self: Secs) Mins {
        return Mins{ .val = self.val / SEC_PER_MIN };
    }
    pub inline fn to_msecs(self: Secs) MSecs {
        return MSecs{ .val = self.val * MS_PER_SEC };
    }
    pub inline fn to_usecs(self: Secs) USecs {
        return USecs{ .val = self.val * US_PER_SEC };
    }
    pub inline fn to_nsecs(self: Secs) NSecs {
        return NSecs{ .val = self.val * NS_PER_SEC };
    }
};
pub const MSecs = extern struct {
    val: i64 = 0,

    pub inline fn new(val: i64) MSecs {
        return MSecs{ .val = val };
    }

    pub inline fn now() MSecs {
        return MSecs{ .val = std.time.milliTimestamp() };
    }

    pub inline fn add(self: MSecs, t: MSecs) MSecs {
        return MSecs{ .val = self.val + t.val };
    }
    pub inline fn sub(self: MSecs, t: MSecs) MSecs {
        return MSecs{ .val = self.val - t.val };
    }
    pub inline fn mult(self: MSecs, t: MSecs) MSecs {
        return MSecs{ .val = self.val * t.val };
    }
    pub inline fn div(self: MSecs, t: MSecs) MSecs {
        return MSecs{ .val = self.val / t.val };
    }

    pub inline fn to_years(self: MSecs) Years {
        return Years{ .val = self.val / MS_PER_YEAR_EXACT };
    }
    pub inline fn to_months(self: MSecs) Months {
        return Months{ .val = self.val / MS_PER_MONTH_AVG };
    }
    pub inline fn to_weeks(self: MSecs) Weeks {
        return Weeks{ .val = self.val / MS_PER_WEEK };
    }
    pub inline fn to_days(self: MSecs) Days {
        return Days{ .val = self.val / MS_PER_DAY };
    }
    pub inline fn to_hours(self: MSecs) Hours {
        return Hours{ .val = self.val / MS_PER_HOUR };
    }
    pub inline fn to_mins(self: MSecs) Mins {
        return Mins{ .val = self.val / MS_PER_MIN };
    }
    pub inline fn to_secs(self: MSecs) Secs {
        return Secs{ .val = self.val / MS_PER_SEC };
    }
    pub inline fn to_usecs(self: MSecs) USecs {
        return USecs{ .val = self.val * US_PER_MS };
    }
    pub inline fn to_nsecs(self: MSecs) NSecs {
        return NSecs{ .val = self.val * NS_PER_MS };
    }
};
pub const USecs = extern struct {
    val: i64 = 0,

    pub inline fn new(val: i64) USecs {
        return USecs{ .val = val };
    }

    pub inline fn now() USecs {
        return USecs{ .val = std.time.microTimestamp() };
    }

    pub inline fn add(self: USecs, t: USecs) USecs {
        return USecs{ .val = self.val + t.val };
    }
    pub inline fn sub(self: USecs, t: USecs) USecs {
        return USecs{ .val = self.val - t.val };
    }
    pub inline fn mult(self: USecs, t: USecs) USecs {
        return USecs{ .val = self.val * t.val };
    }
    pub inline fn div(self: USecs, t: USecs) USecs {
        return USecs{ .val = self.val / t.val };
    }

    pub inline fn to_years(self: USecs) Years {
        return Years{ .val = self.val / US_PER_YEAR_EXACT };
    }
    pub inline fn to_months(self: USecs) Months {
        return Months{ .val = self.val / US_PER_MONTH_AVG };
    }
    pub inline fn to_weeks(self: USecs) Weeks {
        return Weeks{ .val = self.val / US_PER_WEEK };
    }
    pub inline fn to_days(self: USecs) Days {
        return Days{ .val = self.val / US_PER_DAY };
    }
    pub inline fn to_hours(self: USecs) Hours {
        return Hours{ .val = self.val / US_PER_HOUR };
    }
    pub inline fn to_mins(self: USecs) Mins {
        return Mins{ .val = self.val / US_PER_MIN };
    }
    pub inline fn to_secs(self: USecs) Secs {
        return Secs{ .val = self.val / US_PER_SEC };
    }
    pub inline fn to_msecs(self: USecs) MSecs {
        return MSecs{ .val = self.val / US_PER_MS };
    }
    pub inline fn to_nsecs(self: USecs) NSecs {
        return NSecs{ .val = self.val * NS_PER_US };
    }
};
pub const NSecs = extern struct {
    val: i64 = 0,

    pub inline fn new(nsecs: i64) NSecs {
        return NSecs{ .val = nsecs };
    }

    pub inline fn add(self: NSecs, t: NSecs) NSecs {
        return NSecs{ .val = self.val + t.val };
    }
    pub inline fn sub(self: NSecs, t: NSecs) NSecs {
        return NSecs{ .val = self.val - t.val };
    }
    pub inline fn mult(self: NSecs, t: NSecs) NSecs {
        return NSecs{ .val = self.val * t.val };
    }
    pub inline fn div(self: NSecs, t: NSecs) NSecs {
        return NSecs{ .val = self.val / t.val };
    }

    pub inline fn to_years(self: NSecs) Years {
        return Years{ .val = self.val / NS_PER_YEAR_EXACT };
    }
    pub inline fn to_months(self: NSecs) Months {
        return Months{ .val = self.val / NS_PER_MONTH_AVG };
    }
    pub inline fn to_weeks(self: NSecs) Weeks {
        return Weeks{ .val = self.val / NS_PER_WEEK };
    }
    pub inline fn to_days(self: NSecs) Days {
        return Days{ .val = self.val / NS_PER_DAY };
    }
    pub inline fn to_hours(self: NSecs) Hours {
        return Hours{ .val = self.val / NS_PER_HOUR };
    }
    pub inline fn to_mins(self: NSecs) Mins {
        return Mins{ .val = self.val / NS_PER_MIN };
    }
    pub inline fn to_secs(self: NSecs) Secs {
        return Secs{ .val = self.val / NS_PER_SEC };
    }
    pub inline fn to_msecs(self: NSecs) MSecs {
        return MSecs{ .val = self.val / NS_PER_MS };
    }
    pub inline fn to_usecs(self: NSecs) USecs {
        return USecs{ .val = self.val / NS_PER_US };
    }
};
