-- **Initial Questions**

-- 1. What range of years for baseball games played does the provided database cover? 

SELECT MIN(yearID), MAX(yearID)
FROM batting

--Answer: 1871-2016

-- 2. Find the name and height of the shortest player in the database. How many games did he play in? What is the name of the team for which he played?

SELECT DISTINCT playerid, namefirst, namelast, height, G_all, teams.name
FROM people
LEFT JOIN appearances
USING (playerid)
LEFT JOIN teams
USING (teamid)
GROUP BY playerid, namefirst, namelast, height, G_all, teams.name
ORDER BY height ASC
LIMIT 1;

-- Answer: Eddie Gaedel, 43 inches tall, played 1 game for the St. Louis Browns


-- 3. Find all players in the database who played at Vanderbilt University. Create a list showing each player’s first and last names as well as the total salary they earned in the major leagues. Sort this list in descending order by the total salary earned. Which Vanderbilt player earned the most money in the majors?

SELECT namefirst, namelast, SUM(salary) AS total_salary
FROM people
JOIN salaries
USING (playerid)
WHERE playerid IN 
	(SELECT DISTINCT playerid
		FROM people
		FULL JOIN salaries
		USING (playerid)
		GROUP BY playerid, namefirst, namelast
		INTERSECT
		SELECT playerid
		FROM collegeplaying
		JOIN schools
		USING (schoolid)
		WHERE schoolname = 'Vanderbilt University')
GROUP BY namefirst, namelast
ORDER BY total_salary DESC;

SELECT SUM(salary)
FROM salaries
WHERE playerid = 'priceda01'
--Answer: David Price earned $81,851,296
	

-- 4. Using the fielding table, group players into three groups based on their position: label players with position OF as "Outfield", those with position "SS", "1B", "2B", and "3B" as "Infield", and those with position "P" or "C" as "Battery". Determine the number of putouts made by each of these three groups in 2016.

SELECT SUM(po),
	CASE WHEN pos = 'OF' THEN 'Outfield'
	WHEN pos = 'SS' OR pos = '1B' OR pos = '2B' OR pos = '3B' THEN 'Infield'
	WHEN pos = 'P' OR pos = 'C' THEN 'Battery'
	END AS position_group
FROM fielding
WHERE yearID = 2016
GROUP BY position_group

--Answer: Battery 41424, Infield 58934, Outfield 29560

   
-- 5. Find the average number of strikeouts per game by decade since 1920. Round the numbers you report to 2 decimal places. Do the same for home runs per game. Do you see any trends?

SELECT ROUND(SUM(so :: numeric)/(SUM(g :: numeric)/2),2)  AS avg_so, ROUND(SUM(hr :: numeric)/(SUM(g :: numeric)/2),2) AS avg_hr_per_game,
	CASE WHEN yearid BETWEEN 1920 AND 1929 THEN '1920s'
	WHEN yearid BETWEEN 1930 AND 1939 THEN '1930s'
	WHEN yearid BETWEEN 1940 AND 1949 THEN '1940s'
	WHEN yearid BETWEEN 1950 AND 1959 THEN '1950s'
	WHEN yearid BETWEEN 1960 AND 1969 THEN '1960s'
	WHEN yearid BETWEEN 1970 AND 1979 THEN '1970s'
	WHEN yearid BETWEEN 1980 AND 1989 THEN '1980s'
	WHEN yearid BETWEEN 1990 AND 1999 THEN '1990s'
	WHEN yearid BETWEEN 2000 AND 2009 THEN '2000s'
	WHEN yearid BETWEEN 2010 AND 2019 THEN '2010s'
	END AS decade
FROM teams
GROUP BY decade
ORDER BY decade

---Answer: players are progressively getting better: more homeruns, more strikeouts

-- 6. Find the player who had the most success stealing bases in 2016, where __success__ is measured as the percentage of stolen base attempts which are successful. (A stolen base attempt results either in a stolen base or being caught stealing.) Consider only players who attempted _at least_ 20 stolen bases.
	
SELECT namefirst, namelast, steal_attempts, ROUND((sb/steal_attempts)*100,2) AS success_percentage
FROM (
	SELECT namefirst, namelast, (sb :: numeric + cs :: numeric) AS steal_attempts, sb, cs, yearid
	FROM people
	JOIN batting
	USING (playerid)
	WHERE sb <> 0
	AND cs <> 0
	AND yearid = 2016
	) AS subquery
WHERE steal_attempts >=20	
GROUP BY namefirst, namelast, sb, steal_attempts
ORDER BY success_percentage DESC

--Answer: Chris Owings

-- 7.  From 1970 – 2016, what is the largest number of wins for a team that did not win the world series? What is the smallest number of wins for a team that did win the world series? Doing this will probably result in an unusually small number of wins for a world series champion – determine why this is the case. Then redo your query, excluding the problem year. How often from 1970 – 2016 was it the case that a team with the most wins also won the world series? What percentage of the time?

--Teams table- wins/losses WSWin

SELECT name, yearid, w
FROM teams
WHERE wswin <> 'Y'
AND yearID BETWEEN 1970 AND 2016
GROUP BY name, yearid, w
ORDER BY w DESC

--Answer 1: Seattle Mariners won 116 games in 2001

SELECT name, yearid, w
FROM teams
WHERE wswin = 'Y'
AND yearID BETWEEN 1970 AND 2016
GROUP BY name, yearid, w
ORDER BY w ASC

--Answer 2: Los Angeles Dodgers won 63 games in 1981. According to wikipedia this was due to a players' strike, which split the season into two halves

SELECT name, yearid, w
FROM teams
WHERE wswin = 'Y'
AND yearID BETWEEN 1970 AND 2016
AND yearID <> 1981
GROUP BY name, yearid, w
ORDER BY w ASC

--Answer 3: taking out the 1981 series, the lowest wins for a WS winner is 83 games for the St. Louis Cardinals in 2006

--How often from 1970 – 2016 was it the case that a team with the most wins also won the world series? What percentage of the time?

with maxwins AS (
	SELECT yearid, MAX(w) AS mostwins
	FROM teams
	GROUP BY yearid
	),
cte AS (
	SELECT t.yearid, t.name, mostwins, t.wswin, SUM(CASE WHEN wswin ='Y' THEN 1 ELSE 0 END) :: numeric AS wins
FROM teams AS t
LEFT JOIN maxwins AS m
ON t.yearid = m.yearid AND t.w = m.mostwins
WHERE t.yearid > 1969
AND m.mostwins IS NOT NULL
AND wswin IS NOT NULL
GROUP BY t.yearid, t.name, mostwins, t.wswin
ORDER BY t.yearid
	)
SELECT SUM(wins) OVER () / COUNT(yearid) OVER () *100 AS percent_winners
FROM cte

--Answer: 23.08%

-- 8. Using the attendance figures from the homegames table, find the teams and parks which had the top 5 average attendance per game in 2016 (where average attendance is defined as total attendance divided by number of games). Only consider parks where there were at least 10 games played. Report the park name, team name, and average attendance. Repeat for the lowest 5 average attendance.


SELECT park_name, h.team, t.name, (h.attendance/h.games) AS avg_attendance
FROM homegames AS h
JOIN parks AS p
USING (park)
JOIN teams AS t
ON h.team = t.teamid AND h.year = t.yearid
WHERE year = 2016
AND games >= 10
ORDER BY avg_attendance DESC
LIMIT 5;

SELECT park_name, h.team, t.name, (h.attendance/h.games) AS avg_attendance
FROM homegames AS h
JOIN parks AS p
USING (park)
JOIN teams AS t
ON h.team = t.teamid AND h.year = t.yearid
WHERE year = 2016
AND games >= 10
ORDER BY avg_attendance ASC
LIMIT 5;

-- 9. Which managers have won the TSN Manager of the Year award in both the National League (NL) and the American League (AL)? Give their full name and the teams that they were managing when they won the award.

SELECT DISTINCT (a.yearid), a.playerid, p.namefirst, p.namelast, t.name, a.lgid
FROM people AS p
LEFT JOIN awardsmanagers AS a
USING (playerid)
LEFT JOIN managers AS m
ON m.yearid = a.yearid
AND m.playerid = a.playerid
LEFT JOIN teams AS t
ON m.teamid = t.teamid
AND m.yearid = t.yearid
WHERE a.playerid IN 
		(SELECT playerid
		FROM awardsmanagers
		WHERE awardid = 'TSN Manager of the Year'
		AND lgid =  'AL'
		INTERSECT
		SELECT playerid
		FROM awardsmanagers
		WHERE awardid = 'TSN Manager of the Year'
		AND lgid = 'NL')

-- 10. Find all players who hit their career highest number of home runs in 2016. Consider only players who have played in the league for at least 10 years, and who hit at least one home run in 2016. Report the players' first and last names and the number of home runs they hit in 2016.

with maxhr AS (
SELECT playerid, yearid, MAX(hr) AS max
FROM batting
GROUP BY playerid, yearid
HAVING MAX(hr) >= 1
ORDER BY yearid)

SELECT namefirst, namelast, maxhr.max
FROM people
JOIN maxhr
USING (playerid)
WHERE yearid = 2016
AND people.debut :: date < '2006-01-01'
ORDER BY max DESC;

-- **Open-ended questions**

-- 11. Is there any correlation between number of wins and team salary? Use data from 2000 and later to answer this question. As you do this analysis, keep in mind that salaries across the whole league tend to increase together, so you may want to look on a year-by-year basis.

SELECT s.teamid, s.yearid, SUM(salary) AS teamsalary, t.w, 
	AVG(SUM(salary)) OVER (PARTITION BY s.teamid) AS avg_team_salary,
	AVG(t.w) OVER (PARTITION BY s.teamid) AS avg_wins,
	SUM(salary)-(AVG(SUM(salary)) OVER (PARTITION BY s.teamid)) AS salary_diff,
	t.w - (AVG(t.w) OVER (PARTITION BY s.teamid))AS win_diff
FROM salaries AS s
FULL JOIN teams AS t
ON s.yearid = t.yearid
AND s.teamid = t.teamid
WHERE s.yearid >= 2000
GROUP BY s.teamid, s.yearid, t.w
ORDER BY teamid, yearid


-- 12. In this question, you will explore the connection between number of wins and attendance.
--     <ol type="a">
--       <li>Does there appear to be any correlation between attendance at home games and number of wins? </li>
--       <li>Do teams that win the world series see a boost in attendance the following year? What about teams that made the playoffs? Making the playoffs means either being a division winner or a wild card winner.</li>
--     </ol>


-- 13. It is thought that since left-handed pitchers are more rare, causing batters to face them less often, that they are more effective. Investigate this claim and present evidence to either support or dispute this claim. First, determine just how rare left-handed pitchers are compared with right-handed pitchers. Are left-handed pitchers more likely to win the Cy Young Award? Are they more likely to make it into the hall of fame?

  
