if object_id('tempdb..#calendarTbl') is not null drop table #calendarTbl
;
create table #calendarTbl (
	fullDate date primary key
	,dowName nvarchar(10)
	,dowNum int
	,isBusDay int
	,holiday int
)
;
declare @startDate date;
declare @endDate date;

set @startDate = '2019-01-01';
set @endDate = dateadd(yy, 5, datefromparts(year(getdate()),12,31));

while @startDate <= @endDate
	begin
		insert into #calendarTbl
			select 
				@startDate
				,datename(weekday, @startDate)
				,datepart(weekday, @startDate)
				,isBusDay =
					case
						when datepart(weekday, @startDate) in (1, 7)
							then 0
						else 1
					end
				,holiday = 0
		set @startDate = dateadd(dd, 1, @startDate)
	end
;

declare @staticHolidays table(
	holidayMonth int
	,holidayDay int
)
insert into @staticHolidays values
	(12,25)  -- Xmas
	,(01,01) -- New Years
	,(07,04) -- Fourth of July
	,(11,11) -- Veteran's Day
;
with firstHolidays as (
	select 
		cal.* 
	from #calendarTbl cal
	where
		exists (
			select
				*
			from @staticHolidays sth
			where
				month(cal.fullDate) = sth.holidayMonth
				and day(cal.fullDate) = sth.holidayDay
		)
		or exists (
			select
				*
			from @staticHolidays sth
			where
				month(cal.fullDate) = sth.holidayMonth
				and day(cal.fullDate) = (sth.holidayDay + 1)
				and cal.dowNum = 2
		)
		or exists (
			select
				*
			from @staticHolidays sth
			where
				((month(cal.fullDate) = sth.holidayMonth
				and day(cal.fullDate) = (sth.holidayDay - 1))
					or
				(month(cal.fullDate) = 12
				and day(cal.fullDate) = 31))			
				and cal.dowNum = 6
		)
)

update cal
	set
		cal.isBusDay = 0
		,cal.holiday = 1
from #calendarTbl cal
inner join firstHolidays fhl on fhl.fullDate = cal.fullDate

declare @variableHolidays table(
	varMo int
	,varDow int
	,varWhichOne int
)
insert into @variableHolidays values
	(01,02,03) -- MLK
	,(02, 02, 03) -- President's Day
	,(05,02,99) -- Memorial Day
	,(09,02,01) -- Labor Day
	,(11,05,04)  -- Thanksgiving
;
with
secondHolidaysPrep as (
	select
		cal.*
		,dowRnAsc = row_number() over(partition by month(cal.fullDate), year(cal.fullDate), cal.dowNum order by cal.fullDate)
		,dowRnDesc = row_number() over(partition by month(cal.fullDate), year(cal.fullDate), cal.dowNum order by cal.fullDate desc) + 98
	from #calendarTbl cal
)
,secondHolidays as (
	select
		shp.*
	from secondHolidaysPrep shp
	where
		exists (
			select
				*
			from @variableHolidays vhl
			where
				month(shp.fullDate) = vhl.varMo
				and shp.dowNum = vhl.varDow
				and (
					shp.dowRnAsc = vhl.varWhichOne
					or shp.dowRnDesc = vhl.varWhichOne
				)
		)
)
update cal
	set
		cal.isBusDay = 0
		,cal.holiday = 1
from #calendarTbl cal
inner join secondHolidays shl on shl.fullDate = cal.fullDate

select * from #calendarTbl