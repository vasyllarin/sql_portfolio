-- IMDB DATA EXPLORATION

-- [1] AVERAGE RATING BY GENRE
-- (in cte table we join ratings to movie titles
-- then we identify the genre rating using cross join and knowing that each movie can have up to 3 genres)
with cte as (
select bs.primary_title as title, 
       bs.genres,
       rt.averageRating as rating
from title_basics bs
inner join title_ratings rt
on bs.tconst = rt.tconst
where bs.title_type = 'movie'
and bs.genres is not null
)
select substring_index(substring_index(genres, ',', numbers.n), ',', -1) as individual_genre,
       count(*) as movies_quantity,
       round(avg(rating), 4) as average_rating
from cte
cross join (
    select 1 as n union all
    select 2 union all
    select 3
) as numbers
where n <= length(genres) - length(replace(genres, ',', '')) + 1
group by individual_genre
order by avg(rating) desc;

-- [2] INFORMATION ABOUT DIRECTORS: BIRTH/DEATH YEARS, CAREER YEARS, TOTAL VOTES, AVERAGE RATING, HIGHEST RATED MOVIES
-- recursive cte1 creates a table with 1 column that contains numbers from 1 to 86 (max number of directors per movie)
with recursive cte1 (n) as (
select 1
union all
select n + 1
from cte1
where n <= 85
),
-- cte2 creates a table with all the main information and reformats the data
-- so that each director is in a separate row 
cte2 as (
select bs.primary_title as movie_name,
       bs.start_year as year,
       rt.averageRating as rating,
       rt.numVotes as votes,
       -- substring_index construction allows to select 1 director from a comma-separated list
       substring_index(substring_index(cr.directors, ',', cte1.n), ',', -1) as director
from title_crew cr
join title_basics bs
on cr.tconst = bs.tconst
join title_ratings rt
on cr.tconst = rt.tconst
-- cross join allows to create as many rows for one movie as there are directors
cross join cte1
-- 'where' conditon below ensures that the number of rows equals to the number of directors and no more 
-- otherwise, we would have 86 rows for each movie regardless of the number of directors
where cte1.n <= length(cr.directors) - length(replace(cr.directors, ',', '')) + 1
and bs.title_type = 'movie'
and cr.directors is not null
),
-- cte3 summarizes information by director and sorts it by number of votes in descending order
-- (all key information is summarized here, except for 'highest_rated_movie' which is added in the final selection below)
cte3 as (
select cte2.director as director_id,
       nm.primary_name as director_name,
       ifnull(nm.birth_year, 'unknown') as birth_year,
       ifnull(nm.death_year, '-') as death_year,
       count(cte2.movie_name) as movies_number,
       min(cte2.year) as first_movie_year,
       case when nm.birth_year is null then 'unknown' else min(cte2.year) - nm.birth_year end as career_start_age,
       max(cte2.year) as last_movie_year,
       sum(cte2.votes) as total_votes,
       round(avg(cte2.rating), 5) as average_rating,
       max(cte2.rating) as highest_rating
from cte2
join name_basics nm
on cte2.director = nm.nconst
group by director_id
having total_votes > 1000
)
-- final select below identifies movie(s) with the highest rating and adds it(them) in the last column
select cte3.*,
       -- group_concat is used to concatenate 2 or more movies into one string if there are more than 1 movie with the highest rating
       group_concat(mv.movie_name order by mv.rating desc separator '; ') as highest_rated_movie
from cte3
join (select cte2.*,
             rank() over (partition by cte2.director order by cte2.rating desc) as movie_rank
      from cte2) as mv
on cte3.director_id = mv.director
where mv.movie_rank = 1
group by cte3.director_id
order by cte3.total_votes desc;

-- [3] SERIES SUMMARY: YEARS, EPISODES, RUNTIME, RATING
-- cte supplements information about episodes and series (names, genres, years, runtime)
with cte as (
select ep.tconst as episode_id,
       ep.parentTconst as series_id,
       bsp.primary_title as series_name,
       bsp.genres,
       ep.seasonNumber as season,
       ep.episodeNumber as episode,
       bs.start_year as episode_year,
       bs.runtime_minutes as runtime_minutes,
       sum(bs.runtime_minutes) over(partition by ep.parentTconst) as series_runtime_minutes,
       count(ep.tconst) over(partition by ep.parentTconst) as episodes_count
from title_episode ep
join title_basics bs
on ep.tconst = bs.tconst
join title_basics bsp
on ep.parentTconst = bsp.tconst
where bs.genres not like '%documentary%' 
and bs.genres not like '%news%'
and bs.genres not like '%sport%'
and bs.genres not like '%reality%'
and bs.genres not like '%talk-show%'
and bs.genres not like '%game%'
and bs.is_adult = 0
)
-- select below summarizes information by series and adds information about rating
select series_name,
       genres, 
       ifnull(min(episode_year), '- no info -') as start_year,
       ifnull(max(episode_year), '- no info -') as end_year,
       episodes_count,
       -- condition below converts runtime minutes to 'days, hours, minutes' format
       ifnull(concat(floor(series_runtime_minutes/(24*60)), 'd ', 
                     floor(series_runtime_minutes/60) - 24*floor(series_runtime_minutes/(24*60)), 'h ', 
                     mod(series_runtime_minutes,60), 'm'), '- no info -') 
                     as runtime,
	   ifnull(rt.averageRating, '- no info -') as rating 
from cte
left join title_ratings rt
on cte.series_id = rt.tconst
group by series_id
order by episodes_count desc;

-- [4] DIRECTORS LIFE DURATION BY MOVIE GENRE
-- first, we create an index to improve query performance
create index idx_gen on title_basics (genres(255));
-- recursive cte1 creates a table with 1 column that contains numbers from 1 to 86 (max number of directors per movie)
with recursive cte1 (n) as (
select 1
union all
select n + 1
from cte1
where n <= 86
),
-- cte2 creates a list of movies, directors and genres and reformats the data
-- so that each director and each individual genre are in separate rows
cte2 as (
select cr.tconst as movie_id,
       -- substring_index construction allows to select 1 director and 1 genre from a comma-separated list
       substring_index(substring_index(cr.directors, ',', cte1.n), ',', -1) as director_id,
       substring_index(substring_index(bs.genres, ',', one_to_three.n), ',', -1) as genre
from title_crew cr
join title_basics bs
on cr.tconst = bs.tconst
-- cross joins allow to create as many rows for one movie as there are directors and genres
cross join cte1
cross join (
    select 1 as n union all
    select 2 union all
    select 3
) as one_to_three
-- 'where' conditons below ensure that the number of rows equals to the actual number of directors&genres and no more 
where cte1.n <= length(cr.directors) - length(replace(cr.directors, ',', '')) + 1
and one_to_three.n <= length(bs.genres) - length(replace(bs.genres, ',', '')) + 1
and cr.directors is not null
and bs.title_type = 'movie'
and bs.genres is not null
and bs.genres not like '%news%'
and bs.genres not like '%documentary%'
and bs.genres not like '%reality%'
and bs.genres not like '%talk-show%'
and bs.genres not like '%adult%'
order by movie_id
),
-- cte3 calculates age of directors for further summary
cte3 as (
select nm.nconst as director_id,
       nm.death_year - nm.birth_year as age
from name_basics nm
where nm.birth_year is not null
and nm.death_year is not null
and nm.death_year - nm.birth_year > 10
and nm.primary_profession like '%director%'
)
-- final select summarizes information by genre (number of unique directors and average life duration of directors)
select cte2.genre,
       count(distinct cte2.director_id) as unique_directors_count,
       round(avg(cte3.age), 1) as average_directors_age
from cte2
join cte3
on cte2.director_id = cte3.director_id
group by cte2.genre
order by average_directors_age desc;