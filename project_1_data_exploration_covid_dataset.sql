-- COVID DATA EXPLORATION

-- [1] Total cases vs total deaths
-- (shows the likelihood of death if you have covid in Ukraine after 1 April 2020)
select location, 
       date, 
       total_cases, 
       total_deaths, 
       round(total_deaths / total_cases * 100, 1) as death_percentage
from covid_data.covid_deaths
where location = 'ukraine'
and date >= str_to_date('2020-04-01', '%Y-%m-%d')
order by date asc;

-- [2] Total cases vs population
-- (shows the percentage of population infected with covid in Ukraine)
select location,
       date,
       population,
       total_cases,
       round(total_cases / population * 100, 3) as infection_percentage
from covid_deaths
where location = 'ukraine'
and date >= str_to_date('2020-04-01', '%Y-%m-%d')
order by date asc;

-- [3] Infection rate by country from the highest to the lowest
select location,
       population,
       max(total_cases) as infected_people,
       max(round(total_cases / population * 100, 2)) as infection_percentage
from covid_deaths
where continent != ''
group by location
order by infection_percentage desc;

-- [4] Death count by contry from the highest to the lowest
select location,
       max(total_deaths) as death_count
from covid_deaths
where continent != ''
group by location
order by death_count desc;

-- [5] Daily death rate across the world
select date,
       sum(new_cases) as total_cases,
       sum(new_deaths) as total_deaths,
       round(sum(new_deaths) / sum(new_cases) * 100, 3) as death_rate
from covid_deaths
where continent != ''
group by date
order by date asc;

-- [6] Infection and death rates by continent
-- (in cte table we summarize key info by country and then we calculate metrics per continents)
with cte as (
select continent,
       location as country,
       population as country_population,
       max(total_cases) as country_cases,
       max(total_deaths) as country_deaths
from covid_deaths
where continent != ''
group by location
order by continent, location
)
select distinct continent, 
       sum(country_population) over(partition by continent) as continent_population,
       sum(country_cases) over(partition by continent) as continent_cases,
       sum(country_deaths) over(partition by continent) as continent_deaths,
       round(sum(country_cases) over(partition by continent) / sum(country_population) over(partition by continent) * 100, 3) as infection_rate,
       round(sum(country_deaths) over(partition by continent) / sum(country_cases) over(partition by continent) * 100, 3) as death_rate
from cte
order by death_rate desc;

-- [7] Population vs number of vaccinations per country and per day
select dt.continent,
       dt.location,
       dt.date,
       dt.population,
       vc.new_vaccinations,
       sum(vc.new_vaccinations) over(partition by dt.location order by dt.location, dt.date) as vaccinations_cumulative
from covid_deaths dt
left join covid_vaccinations vc
on dt.location = vc.location and dt.date = vc.date
where dt.continent != ''
order by dt.location, dt.date;

-- [8] Vaccination rate per country and per day
with pop_vs_vac (continent, location, date, population, new_vaccinations, vaccinations_cumulative)
as (       
select dt.continent,
       dt.location,
       dt.date,
       dt.population,
       vc.new_vaccinations,
       sum(vc.new_vaccinations) over(partition by dt.location order by dt.date) as vaccinations_cumulative
from covid_deaths dt
left join covid_vaccinations vc
on dt.location = vc.location and dt.date = vc.date
where dt.continent != ''
order by dt.location, dt.date
)
select *, round(vaccinations_cumulative / population * 100, 2) as vaccination_rate
from pop_vs_vac;

-- [9] Creating new table based on the previous query
create table vaccinations_cumulative (
continent varchar(255),
location varchar(255),
date date,
populaton int,
new_vaccinations int,
vaccinations_cumulative int
);
insert into vaccinations_cumulative
select dt.continent,
       dt.location,
       dt.date,
       dt.population,
       vc.new_vaccinations,
       sum(vc.new_vaccinations) over(partition by dt.location order by dt.date) as vaccinations_cumulative
from covid_deaths dt
left join covid_vaccinations vc
on dt.location = vc.location and dt.date = vc.date
where dt.continent != ''
order by dt.location, dt.date;

-- [10] Creating view
create view vaccinations_cumulative_view as
select dt.continent,
       dt.location,
       dt.date,
       dt.population,
       vc.new_vaccinations,
       sum(vc.new_vaccinations) over(partition by dt.location order by dt.date) as vaccinations_cumulative
from covid_deaths dt
left join covid_vaccinations vc
on dt.location = vc.location and dt.date = vc.date
where dt.continent != ''
order by dt.location, dt.date;
