unit Collector.Scripts;

interface

function BuildReadinessScript: string;
function BuildStatisticsExtractionScript: string;
function BuildLineupsExtractionScript: string;
function BuildPlayerStatsExtractionScript(
  const ACategory: string): string;
function BuildCommentaryExtractionScript: string;
function BuildMatchDiscoveryScript(const AArchive2022: Boolean): string;

implementation

uses
  System.SysUtils;

{$TEXTBLOCK CRLF}

function BuildReadinessScript: string;
begin
  Result := '''
    (() => {
      const path = location.pathname.toLowerCase();
      const readyStateOk = document.readyState === 'complete' ||
        document.readyState === 'interactive';
      let section = 'unknown';
      let count = 0;
      if (path.includes('/stats/extra-time/')) {
        section = 'statistics_extra_time';
        count = document.querySelectorAll(
          '[data-testid="wcl-statistics"]'
        ).length;
      } else if (path.includes('/stats/1st-half/')) {
        section = 'statistics_first_half';
        count = document.querySelectorAll(
          '[data-testid="wcl-statistics"]'
        ).length;
      } else if (path.includes('/stats/2nd-half/')) {
        section = 'statistics_second_half';
        count = document.querySelectorAll(
          '[data-testid="wcl-statistics"]'
        ).length;
      } else if (path.includes('/stats/')) {
        section = 'statistics_overall';
        count = document.querySelectorAll(
          '[data-testid="wcl-statistics"]'
        ).length;
      } else if (path.includes('/lineups/')) {
        section = 'lineups';
        count = document.querySelectorAll(
          '[data-testid*="lineup"], .lf__participant, [class*="lineup"]'
        ).length;
      } else if (path.includes('/player-stats/')) {
        section = 'player_stats';
        count = document.querySelectorAll(
          'table tbody tr, [data-testid*="player"], [class*="playerStats"]'
        ).length;
      } else if (path.includes('/live-commentary/')) {
        section = 'commentary';
        count = document.querySelectorAll(
          '[data-testid*="incident"], .smv__incident, [class*="commentary"]'
        ).length;
      }
      const bodyTextLength = document.body && document.body.innerText
        ? document.body.innerText.length : 0;
      const sectionRequiresRows = section !== 'unknown';
      return {
        ready: readyStateOk && (
          sectionRequiresRows ? count > 0 : bodyTextLength > 500
        ),
        section: section,
        row_count: count,
        body_text_length: bodyTextLength,
        title: document.title || ''
      };
    })();
    ''';
end;

function BuildStatisticsExtractionScript: string;
begin
  Result := '''
    (() => {
     try {
     const text = e => {
       if (!e) return null;
       const value = (typeof e.innerText === 'string')
         ? e.innerText
         : ((typeof e.textContent === 'string') ? e.textContent : '');
       const trimmed = value.trim();
       return trimmed.length > 0 ? trimmed : null;
     };
     const normalize = value => value ? value.replace(/\s+/g, ' ').trim() : null;
     const all = (root, sel) => Array.from(root.querySelectorAll(sel));
     const firstText = selectors => {
       for (const s of selectors) {
         const value = text(document.querySelector(s));
         if (value) return value;
       }
       return null;
     };
     const uniqueTexts = values => {
       const seen = new Set();
       return values.filter(value => {
         if (!value) return false;
         const key = value.toLowerCase();
         if (seen.has(key)) return false;
         seen.add(key);
         return true;
       });
     };
     const title = document.title || '';
     const titleMatch = title.match(/^(.+?)\s+(\d+)\s*-\s*(\d+)\s+(.+?)\s+\|/);
     const path = location.pathname.toLowerCase();
     let section = 'unknown';
     let statisticPeriod = null;
     if (path.includes('/stats/extra-time/')) {
       section = 'statistics_extra_time';
       statisticPeriod = 'extra_time';
     } else if (path.includes('/stats/1st-half/')) {
       section = 'statistics_first_half';
       statisticPeriod = 'first_half';
     } else if (path.includes('/stats/2nd-half/')) {
       section = 'statistics_second_half';
       statisticPeriod = 'second_half';
     } else if (path.includes('/stats/')) {
       section = 'statistics_overall';
       statisticPeriod = 'overall';
     } else if (path.includes('/lineups/')) section = 'lineups';
     else if (path.includes('/player-stats/')) section = 'player_stats';
     else if (path.includes('/live-commentary/')) section = 'commentary';
     const homeTeam = firstText([
       '.duelParticipant__home .participant__participantName',
       '.duelParticipant__home [class*="participantName"]',
       '[data-testid="wcl-participant-home"]'
     ]);
     const awayTeam = firstText([
       '.duelParticipant__away .participant__participantName',
       '.duelParticipant__away [class*="participantName"]',
       '[data-testid="wcl-participant-away"]'
     ]);
     const homeScore = firstText([
       '.detailScore__wrapper span:first-child',
       '.detailScore__wrapper > div:first-child',
       '[data-testid="wcl-home-score"]'
     ]);
     const awayScore = firstText([
       '.detailScore__wrapper span:last-child',
       '.detailScore__wrapper > div:last-child',
       '[data-testid="wcl-away-score"]'
     ]);
     const scoreWrapper = firstText([
       '.detailScore__wrapper',
       '[data-testid="wcl-detail-score"]'
     ]);
     const competitionText = firstText([
       '.tournamentHeader__country',
       '.tournamentHeader__sportContent',
       '.tournamentHeader__name',
       '[data-testid="wcl-tournament-header"]'
     ]);
     const statusText = firstText([
       '.detailScore__status',
       '[data-testid="wcl-status"]'
     ]);
     const dateTimeText = firstText([
       '.duelParticipant__startTime',
       '[data-testid="wcl-match-info"]'
     ]);
     const result = {
       schema_version: '1.3',
       section: section,
       statistic_period: statisticPeriod,
       source_url: location.href,
       match_id: new URL(location.href).searchParams.get('mid'),
       collected_at_utc: new Date().toISOString(),
       page_title: title || null,
       competition: competitionText || 'WORLD CUP',
       status: statusText,
       date_time: dateTimeText,
       home_team: homeTeam || (titleMatch ? titleMatch[1].trim() : null),
       away_team: awayTeam || (titleMatch ? titleMatch[4].trim() : null),
       score: {
         home: homeScore || (titleMatch ? titleMatch[2] : null),
         away: awayScore || (titleMatch ? titleMatch[3] : null),
         display: normalize(scoreWrapper) ||
           (titleMatch ? (titleMatch[2] + '-' + titleMatch[3]) : null)
       }
     };
     if (section.startsWith('statistics_')) {
       const rawRows = all(document, '[data-testid="wcl-statistics"]')
         .map(row => {
           const category = normalize(text(row.querySelector(
             '[data-testid="wcl-statistics-category"]')));
           const values = all(row, '[data-testid="wcl-statistics-value"]')
             .map(text).filter(v => v !== null);
           return {
             category: category,
             home: values.length > 0 ? values[0] : null,
             away: values.length > 1 ? values[1] : null,
             raw_values: values
           };
         }).filter(x => x.category);
       const seen = new Set();
       result.statistics = rawRows.filter(row => {
         const key = [row.category, row.home || '', row.away || '']
           .join('\u001f').toLowerCase();
         if (seen.has(key)) return false;
         seen.add(key);
         return true;
       });
       result.extraction_diagnostics = {
         statistic_period: statisticPeriod,
         raw_statistic_row_count: rawRows.length,
         statistic_row_count: result.statistics.length,
         duplicate_statistic_row_count: rawRows.length - result.statistics.length
       };
     }
     return JSON.stringify(result);
     } catch (e) {
       return JSON.stringify({
         extraction_error: String(e && e.stack ? e.stack : e),
         source_url: location.href,
         collected_at_utc: new Date().toISOString()
       });
     }
    })();
    ''';
end;

function BuildLineupsExtractionScript: string;
begin
  Result := '''
    (() => {
     try {
     const text = e => {
       if (!e) return null;
       const value = (typeof e.innerText === 'string')
         ? e.innerText
         : ((typeof e.textContent === 'string') ? e.textContent : '');
       const trimmed = value.trim();
       return trimmed.length > 0 ? trimmed : null;
     };
     const normalize = value => value ? value.replace(/\s+/g, ' ').trim() : null;
     const all = (root, sel) => Array.from(root.querySelectorAll(sel));
     const firstText = selectors => {
       for (const s of selectors) {
         const value = text(document.querySelector(s));
         if (value) return value;
       }
       return null;
     };
     const uniqueTexts = values => {
       const seen = new Set();
       return values.filter(value => {
         if (!value) return false;
         const key = value.toLowerCase();
         if (seen.has(key)) return false;
         seen.add(key);
         return true;
       });
     };
     const title = document.title || '';
     const titleMatch = title.match(/^(.+?)\s+(\d+)\s*-\s*(\d+)\s+(.+?)\s+\|/);
     const path = location.pathname.toLowerCase();
     let section = 'unknown';
     let statisticPeriod = null;
     if (path.includes('/stats/extra-time/')) {
       section = 'statistics_extra_time';
       statisticPeriod = 'extra_time';
     } else if (path.includes('/stats/1st-half/')) {
       section = 'statistics_first_half';
       statisticPeriod = 'first_half';
     } else if (path.includes('/stats/2nd-half/')) {
       section = 'statistics_second_half';
       statisticPeriod = 'second_half';
     } else if (path.includes('/stats/')) {
       section = 'statistics_overall';
       statisticPeriod = 'overall';
     } else if (path.includes('/lineups/')) section = 'lineups';
     else if (path.includes('/player-stats/')) section = 'player_stats';
     else if (path.includes('/live-commentary/')) section = 'commentary';
     const homeTeam = firstText([
       '.duelParticipant__home .participant__participantName',
       '.duelParticipant__home [class*="participantName"]',
       '[data-testid="wcl-participant-home"]'
     ]);
     const awayTeam = firstText([
       '.duelParticipant__away .participant__participantName',
       '.duelParticipant__away [class*="participantName"]',
       '[data-testid="wcl-participant-away"]'
     ]);
     const homeScore = firstText([
       '.detailScore__wrapper span:first-child',
       '.detailScore__wrapper > div:first-child',
       '[data-testid="wcl-home-score"]'
     ]);
     const awayScore = firstText([
       '.detailScore__wrapper span:last-child',
       '.detailScore__wrapper > div:last-child',
       '[data-testid="wcl-away-score"]'
     ]);
     const scoreWrapper = firstText([
       '.detailScore__wrapper',
       '[data-testid="wcl-detail-score"]'
     ]);
     const competitionText = firstText([
       '.tournamentHeader__country',
       '.tournamentHeader__sportContent',
       '.tournamentHeader__name',
       '[data-testid="wcl-tournament-header"]'
     ]);
     const statusText = firstText([
       '.detailScore__status',
       '[data-testid="wcl-status"]'
     ]);
     const dateTimeText = firstText([
       '.duelParticipant__startTime',
       '[data-testid="wcl-match-info"]'
     ]);
     const result = {
       schema_version: '1.3',
       section: section,
       statistic_period: statisticPeriod,
       source_url: location.href,
       match_id: new URL(location.href).searchParams.get('mid'),
       collected_at_utc: new Date().toISOString(),
       page_title: title || null,
       competition: competitionText || 'WORLD CUP',
       status: statusText,
       date_time: dateTimeText,
       home_team: homeTeam || (titleMatch ? titleMatch[1].trim() : null),
       away_team: awayTeam || (titleMatch ? titleMatch[4].trim() : null),
       score: {
         home: homeScore || (titleMatch ? titleMatch[2] : null),
         away: awayScore || (titleMatch ? titleMatch[3] : null),
         display: normalize(scoreWrapper) ||
           (titleMatch ? (titleMatch[2] + '-' + titleMatch[3]) : null)
       }
     };
     if (section === 'lineups') {
       const rows = all(document,
         '[data-testid*="lineup"], .lf__participant, [class*="lineup"]');
       const allTexts = uniqueTexts(rows.map(row => normalize(text(row))).filter(Boolean));
       const rootText = allTexts.find(value =>
         /FORMATION/i.test(value) && /STARTING LINEUPS/i.test(value)) || null;
       const compactTexts = allTexts
         .filter(value => value.length <= 180)
         .filter(value => !/ODDS\s+1X2/i.test(value));
    
       const substitutionTexts = compactTexts.filter(value =>
         /\d+(?:\+\d+)?'$/.test(value) && !/^\d+(?:\+\d+)?'$/.test(value));
       const firstSubstitutionIndex = substitutionTexts.length > 0
         ? Math.min(...substitutionTexts.map(value => compactTexts.indexOf(value)))
         : -1;
    
       const formationZone = firstSubstitutionIndex >= 0
         ? compactTexts.slice(0, firstSubstitutionIndex)
         : compactTexts.slice(0, 22);
       const formationTexts = formationZone
         .filter(value => /^\d+\s+\S+/.test(value))
         .slice(0, 22);
    
       const lastSubstitutionIndex = substitutionTexts.reduce((resultValue, value) =>
         Math.max(resultValue, compactTexts.indexOf(value)), -1);
       const lastFormationIndex = formationTexts.reduce((resultValue, value) =>
         Math.max(resultValue, compactTexts.indexOf(value)), -1);
       const detailedStartIndex = Math.max(lastSubstitutionIndex, lastFormationIndex) + 1;
    
       const detailedTexts = compactTexts.slice(detailedStartIndex).filter(value =>
         /^\d+\s+\S+/.test(value) &&
         !/\d+(?:\+\d+)?'$/.test(value) &&
         !/\b(?:injury|suspended|illness)\b/i.test(value)
       );
    
       const formationMatch = rootText ? rootText.match(
         /(\d+(?:\s*-\s*\d+)+)\s+FORMATION\s+(\d+(?:\s*-\s*\d+)+)/i
       ) : null;
    
       const normalizeName = value => (value || '')
         .toLowerCase()
         .normalize('NFD')
         .replace(/[\u0300-\u036f]/g, '')
         .replace(/\([gc]\)/g, '')
         .replace(/[^a-z0-9]+/g, ' ')
         .trim();
    
       const nameTokens = value => normalizeName(value).split(/\s+/).filter(Boolean);
    
       const parsePlayer = (value, sourceKind) => {
         const match = value.match(/^(\d+)\s+(.+)$/);
         if (!match) return { raw: value, source: sourceKind || null };
    
         let nameText = match[2];
         let goals = null;
         const goalCountMatch = sourceKind === 'detailed'
           ? nameText.match(/\s+(\d+)$/)
           : null;
    
         if (goalCountMatch) {
           goals = Number(goalCountMatch[1]);
           nameText = nameText.slice(0, goalCountMatch.index).trim();
         }
    
         const player = {
           number: Number(match[1]),
           name: nameText.replace(/\s*\([GC]\)/g, '').trim(),
           goalkeeper: /\(G\)/.test(nameText),
           captain: /\(C\)/.test(nameText),
           raw: value,
           source: sourceKind || null
         };
    
         if (goals !== null) player.goals = goals;
         return player;
       };
    
       const homeFormationBase = formationTexts.slice(0, 11)
         .map(value => parsePlayer(value, 'formation'));
       const awayFormationBase = formationTexts.slice(11, 22)
         .map(value => parsePlayer(value, 'formation'));
       const detailedPlayers = detailedTexts
         .map((value, index) => {
           const player = parsePlayer(value, 'detailed');
           player.detail_index = index;
           return player;
         });
    
       const playerMatchScore = (formationPlayer, detailPlayer) => {
         if (!formationPlayer || !detailPlayer) return -1000;
    
         const formationName = normalizeName(formationPlayer.name);
         const detailName = normalizeName(detailPlayer.name);
         const formationTokens = nameTokens(formationPlayer.name);
         const detailTokens = nameTokens(detailPlayer.name);
         let score = 0;
    
         if (formationPlayer.number === detailPlayer.number) score += 5;
         if (formationName === detailName) score += 12;
         else if (detailName.startsWith(formationName + ' ') ||
                  formationName.startsWith(detailName + ' ')) score += 9;
         else {
           const overlap = formationTokens.filter(token =>
             token.length > 1 && detailTokens.includes(token)).length;
           score += overlap * 4;
           if (formationTokens.length === 1 &&
               detailTokens.includes(formationTokens[0])) score += 4;
         }
    
         return score;
       };
    
       const usedDetailIndexes = new Set();
    
       const resolveStarting = formationPlayers => formationPlayers.map(
         (formationPlayer, formationIndex) => {
           let bestPlayer = null;
           let bestScore = -1000;
    
           for (const detailPlayer of detailedPlayers) {
             if (usedDetailIndexes.has(detailPlayer.detail_index)) continue;
             const score = playerMatchScore(formationPlayer, detailPlayer);
             if (score > bestScore) {
               bestScore = score;
               bestPlayer = detailPlayer;
             }
           }
    
           if (bestPlayer && bestScore >= 8) {
             usedDetailIndexes.add(bestPlayer.detail_index);
             return {
               number: formationPlayer.number,
               name: bestPlayer.name,
               goalkeeper: bestPlayer.goalkeeper || formationIndex === 0,
               captain: bestPlayer.captain,
               raw: bestPlayer.raw,
               formation_raw: formationPlayer.raw,
               source: 'formation_detail_match',
               match_score: bestScore,
               ...(bestPlayer.goals !== undefined ? { goals: bestPlayer.goals } : {})
             };
           }
    
           return {
             number: formationPlayer.number,
             name: formationPlayer.name,
             goalkeeper: formationIndex === 0,
             captain: false,
             raw: formationPlayer.raw,
             formation_raw: formationPlayer.raw,
             source: 'formation_fallback',
             match_score: bestScore
           };
         }
       );
    
       const homeStarting = resolveStarting(homeFormationBase);
       const awayStarting = resolveStarting(awayFormationBase);
    
       const enrichFormationPlayers = (formationPlayers, startingPlayers) =>
         formationPlayers.map((formationPlayer, index) => {
           const startingPlayer = startingPlayers[index] || null;
           return {
             ...formationPlayer,
             goalkeeper: startingPlayer
               ? startingPlayer.goalkeeper
               : index === 0,
             captain: startingPlayer
               ? startingPlayer.captain
               : false
           };
         });
    
       const homeFormationPlayers =
         enrichFormationPlayers(homeFormationBase, homeStarting);
       const awayFormationPlayers =
         enrichFormationPlayers(awayFormationBase, awayStarting);
    
       const nameMatchScore = (candidateName, rosterName) => {
         const candidate = normalizeName(candidateName);
         const roster = normalizeName(rosterName);
         if (!candidate || !roster) return 0;
         if (candidate === roster) return 12;
         if (candidate.startsWith(roster + ' ') || roster.startsWith(candidate + ' '))
           return 9;
    
         const candidateTokens = nameTokens(candidateName);
         const rosterTokens = nameTokens(rosterName);
         return candidateTokens.filter(token =>
           token.length > 1 && rosterTokens.includes(token)).length * 4;
       };
    
       const bestRosterScore = (name, roster) => roster.reduce(
         (bestScore, player) => Math.max(bestScore, nameMatchScore(name, player.name)),
         0
       );
    
       const bestDetailScore = name => detailedPlayers.reduce(
         (bestScore, player) => Math.max(bestScore, nameMatchScore(name, player.name)),
         0
       );
    
       const splitUnratedSubstitution = value => {
         const tokens = value.split(/\s+/).filter(Boolean);
         let best = {
           incoming: value,
           outgoing: null,
           total_score: -1
         };
    
         for (let splitIndex = 1; splitIndex < tokens.length; splitIndex++) {
           const incomingCandidate = tokens.slice(0, splitIndex).join(' ');
           const outgoingCandidate = tokens.slice(splitIndex).join(' ');
           const homeScore = bestRosterScore(outgoingCandidate, homeFormationBase);
           const awayScore = bestRosterScore(outgoingCandidate, awayFormationBase);
           const incomingScore = bestDetailScore(incomingCandidate);
           const totalScore = Math.max(homeScore, awayScore) * 3 + incomingScore;
    
           if (totalScore > best.total_score) {
             best = {
               incoming: incomingCandidate,
               outgoing: outgoingCandidate,
               total_score: totalScore
             };
           }
         }
    
         return best;
       };
    
       const parseSubstitution = value => {
         const minuteMatch = value.match(/(\d+(?:\+\d+)?)'$/);
         const withoutMinute = minuteMatch
           ? value.slice(0, minuteMatch.index).trim() : value;
         const ratingMatch = withoutMinute.match(/\s(\d+\.\d)\s/);
         let incoming = withoutMinute;
         let outgoing = null;
         let rating = null;
         let splitScore = null;
    
         if (ratingMatch) {
           incoming = withoutMinute.slice(0, ratingMatch.index).trim();
           rating = Number(ratingMatch[1]);
           outgoing = withoutMinute.slice(
             ratingMatch.index + ratingMatch[0].length
           ).trim();
         } else {
           const splitResult = splitUnratedSubstitution(withoutMinute);
           incoming = splitResult.incoming;
           outgoing = splitResult.outgoing;
           splitScore = splitResult.total_score;
         }
    
         const homeScore = bestRosterScore(outgoing, homeFormationBase);
         const awayScore = bestRosterScore(outgoing, awayFormationBase);
         let side = null;
    
         if (homeScore >= 4 || awayScore >= 4) {
           side = homeScore >= awayScore ? 'home' : 'away';
         }
    
         return {
           minute: minuteMatch ? minuteMatch[1] : null,
           incoming: incoming || null,
           outgoing: outgoing,
           incoming_rating: rating,
           side: side,
           side_match_score: Math.max(homeScore, awayScore),
           split_match_score: splitScore,
           raw: value
         };
       };
    
       const parsedSubstitutions = substitutionTexts.map(parseSubstitution);
    
       const benchCandidates = detailedPlayers
         .filter(player => !usedDetailIndexes.has(player.detail_index))
         .sort((left, right) => left.detail_index - right.detail_index);
    
       const substitutionEvidence = benchCandidates.map((player, index) => {
         let homeScore = 0;
         let awayScore = 0;
    
         for (const substitution of parsedSubstitutions) {
           const score = nameMatchScore(player.name, substitution.incoming);
           if (substitution.side === 'home') homeScore = Math.max(homeScore, score);
           if (substitution.side === 'away') awayScore = Math.max(awayScore, score);
         }
    
         return {
           index: index,
           home_score: homeScore,
           away_score: awayScore
         };
       });
    
       const minimumBenchSize = benchCandidates.length >= 20
         ? Math.max(10, benchCandidates.length - 16)
         : 0;
       const maximumHomeBenchSize = benchCandidates.length >= 20
         ? Math.min(16, benchCandidates.length - 10)
         : benchCandidates.length;
    
       let homeBenchCount = Math.ceil(benchCandidates.length / 2);
       let bestBoundaryScore = -100000;
    
       for (let boundary = minimumBenchSize;
            boundary <= maximumHomeBenchSize;
            boundary++) {
         let boundaryScore = 0;
    
         for (const evidence of substitutionEvidence) {
           if (evidence.index < boundary) {
             boundaryScore += evidence.home_score * 3;
             boundaryScore -= evidence.away_score * 3;
           } else {
             boundaryScore += evidence.away_score * 3;
             boundaryScore -= evidence.home_score * 3;
           }
         }
    
         boundaryScore -= Math.abs(
           boundary - benchCandidates.length / 2
         ) * 0.05;
    
         if (boundaryScore > bestBoundaryScore) {
           bestBoundaryScore = boundaryScore;
           homeBenchCount = boundary;
         }
       }
    
       const cleanBenchPlayer = player => {
         const resultPlayer = { ...player };
         delete resultPlayer.detail_index;
         return resultPlayer;
       };
    
       const homeSubstitutes = benchCandidates.slice(0, homeBenchCount)
         .map(cleanBenchPlayer);
       const awaySubstitutes = benchCandidates.slice(homeBenchCount)
         .map(cleanBenchPlayer);
    
       const coachSearchTexts = compactTexts.slice(detailedStartIndex);
       const coachCandidates = coachSearchTexts.filter(value =>
         !/^\d+\s/.test(value) &&
         !/\d+(?:\+\d+)?'$/.test(value) &&
         !/\b(?:injury|suspended|illness|formation|starting lineups|substitutes)\b/i
           .test(value) &&
         (
           /^.{3,80}\s[A-Z]\.$/.test(value) ||
           /^[A-ZÀ-Ž][A-Za-zÀ-ž'.-]+(?:\s+[A-ZÀ-Ž][A-Za-zÀ-ž'.-]+){1,4}$/
             .test(value)
         )
       );
       const homeCoach = coachCandidates.length >= 2
         ? coachCandidates[coachCandidates.length - 2] : null;
       const awayCoach = coachCandidates.length >= 1
         ? coachCandidates[coachCandidates.length - 1] : null;
    
       const formationOverlap = (formationPlayers, startingPlayers) =>
         formationPlayers.filter(formationPlayer =>
           startingPlayers.some(startingPlayer =>
             playerMatchScore(formationPlayer, startingPlayer) >= 8
           )
         ).length;
    
       const homeOverlap = formationOverlap(homeFormationBase, homeStarting);
       const awayOverlap = formationOverlap(awayFormationBase, awayStarting);
    
       const homeBenchSubstitutionMatches = parsedSubstitutions
         .filter(item => item.side === 'home')
         .filter(item => bestRosterScore(item.incoming, homeSubstitutes) >= 4).length;
       const awayBenchSubstitutionMatches = parsedSubstitutions
         .filter(item => item.side === 'away')
         .filter(item => bestRosterScore(item.incoming, awaySubstitutes) >= 4).length;
    
       result.lineups = {
         home: {
           formation: formationMatch ? formationMatch[1].replace(/\s+/g, '') : null,
           formation_players: homeFormationPlayers,
           starting: homeStarting,
           substitutes: homeSubstitutes,
           substitutions: parsedSubstitutions.filter(item => item.side === 'home'),
           coach: homeCoach
         },
         away: {
           formation: formationMatch ? formationMatch[2].replace(/\s+/g, '') : null,
           formation_players: awayFormationPlayers,
           starting: awayStarting,
           substitutes: awaySubstitutes,
           substitutions: parsedSubstitutions.filter(item => item.side === 'away'),
           coach: awayCoach
         },
         unassigned_substitutions: parsedSubstitutions.filter(item => !item.side),
         raw: compactTexts
       };
    
       result.lineup_validation = {
         home_formation_count: homeFormationBase.length,
         away_formation_count: awayFormationBase.length,
         home_starting_count: homeStarting.length,
         away_starting_count: awayStarting.length,
         home_substitute_count: homeSubstitutes.length,
         away_substitute_count: awaySubstitutes.length,
         home_starting_formation_overlap: homeOverlap,
         away_starting_formation_overlap: awayOverlap,
         home_starting_valid: homeStarting.length === 11 && homeOverlap === 11,
         away_starting_valid: awayStarting.length === 11 && awayOverlap === 11,
         detailed_player_count: detailedPlayers.length,
         matched_starting_detail_count: usedDetailIndexes.size,
         formation_fallback_count:
           homeStarting.filter(player => player.source === 'formation_fallback').length +
           awayStarting.filter(player => player.source === 'formation_fallback').length,
         unassigned_substitution_count:
           parsedSubstitutions.filter(item => !item.side).length,
         home_bench_substitution_match_count: homeBenchSubstitutionMatches,
         away_bench_substitution_match_count: awayBenchSubstitutionMatches,
         bench_boundary_index: homeBenchCount,
         bench_boundary_score: bestBoundaryScore
       };
    
       result.extraction_diagnostics = {
         raw_lineup_row_count: rows.length,
         compact_lineup_text_count: compactTexts.length,
         formation_zone_count: formationZone.length,
         used_formation_player_count: formationTexts.length,
         detailed_player_count: detailedPlayers.length,
         substitution_count: substitutionTexts.length,
         coach_candidate_count: coachCandidates.length,
         home_coach_found: homeCoach !== null,
         away_coach_found: awayCoach !== null,
         structured_home_starting_count: result.lineups.home.starting.length,
         structured_away_starting_count: result.lineups.away.starting.length,
         structured_home_substitute_count: result.lineups.home.substitutes.length,
         structured_away_substitute_count: result.lineups.away.substitutes.length,
         matched_starting_detail_count: usedDetailIndexes.size,
         formation_fallback_count: result.lineup_validation.formation_fallback_count,
         bench_boundary_index: homeBenchCount
       };
     }
     return JSON.stringify(result);
     } catch (e) {
       return JSON.stringify({
         extraction_error: String(e && e.stack ? e.stack : e),
         source_url: location.href,
         collected_at_utc: new Date().toISOString()
       });
     }
    })();
    ''';
end;

function BuildPlayerStatsExtractionScript(
  const ACategory: string): string;
begin
  Result := '''
    (() => {
     try {
     const text = e => {
       if (!e) return null;
       const value = (typeof e.innerText === 'string')
         ? e.innerText
         : ((typeof e.textContent === 'string') ? e.textContent : '');
       const trimmed = value.trim();
       return trimmed.length > 0 ? trimmed : null;
     };
     const normalize = value => value ? value.replace(/\s+/g, ' ').trim() : null;
     const all = (root, sel) => Array.from(root.querySelectorAll(sel));
     const firstText = selectors => {
       for (const s of selectors) {
         const value = text(document.querySelector(s));
         if (value) return value;
       }
       return null;
     };
     const uniqueTexts = values => {
       const seen = new Set();
       return values.filter(value => {
         if (!value) return false;
         const key = value.toLowerCase();
         if (seen.has(key)) return false;
         seen.add(key);
         return true;
       });
     };
     const title = document.title || '';
     const titleMatch = title.match(/^(.+?)\s+(\d+)\s*-\s*(\d+)\s+(.+?)\s+\|/);
     const path = location.pathname.toLowerCase();
     const requestedPlayerStatsCategory = '__PLAYER_STATS_CATEGORY__';
     let section = 'unknown';
     let statisticPeriod = null;
     if (path.includes('/stats/extra-time/')) {
       section = 'statistics_extra_time';
       statisticPeriod = 'extra_time';
     } else if (path.includes('/stats/1st-half/')) {
       section = 'statistics_first_half';
       statisticPeriod = 'first_half';
     } else if (path.includes('/stats/2nd-half/')) {
       section = 'statistics_second_half';
       statisticPeriod = 'second_half';
     } else if (path.includes('/stats/')) {
       section = 'statistics_overall';
       statisticPeriod = 'overall';
     } else if (path.includes('/lineups/')) section = 'lineups';
     else if (path.includes('/player-stats/'))
       section = 'player_stats_' + requestedPlayerStatsCategory;
     else if (path.includes('/live-commentary/')) section = 'commentary';
     const homeTeam = firstText([
       '.duelParticipant__home .participant__participantName',
       '.duelParticipant__home [class*="participantName"]',
       '[data-testid="wcl-participant-home"]'
     ]);
     const awayTeam = firstText([
       '.duelParticipant__away .participant__participantName',
       '.duelParticipant__away [class*="participantName"]',
       '[data-testid="wcl-participant-away"]'
     ]);
     const homeScore = firstText([
       '.detailScore__wrapper span:first-child',
       '.detailScore__wrapper > div:first-child',
       '[data-testid="wcl-home-score"]'
     ]);
     const awayScore = firstText([
       '.detailScore__wrapper span:last-child',
       '.detailScore__wrapper > div:last-child',
       '[data-testid="wcl-away-score"]'
     ]);
     const scoreWrapper = firstText([
       '.detailScore__wrapper',
       '[data-testid="wcl-detail-score"]'
     ]);
     const competitionText = firstText([
       '.tournamentHeader__country',
       '.tournamentHeader__sportContent',
       '.tournamentHeader__name',
       '[data-testid="wcl-tournament-header"]'
     ]);
     const statusText = firstText([
       '.detailScore__status',
       '[data-testid="wcl-status"]'
     ]);
     const dateTimeText = firstText([
       '.duelParticipant__startTime',
       '[data-testid="wcl-match-info"]'
     ]);
     const result = {
       schema_version: '1.3',
       section: section,
       statistic_period: statisticPeriod,
       player_stats_category: requestedPlayerStatsCategory,
       source_url: location.href,
       match_id: new URL(location.href).searchParams.get('mid'),
       collected_at_utc: new Date().toISOString(),
       page_title: title || null,
       competition: competitionText || 'WORLD CUP',
       status: statusText,
       date_time: dateTimeText,
       home_team: homeTeam || (titleMatch ? titleMatch[1].trim() : null),
       away_team: awayTeam || (titleMatch ? titleMatch[4].trim() : null),
       score: {
         home: homeScore || (titleMatch ? titleMatch[2] : null),
         away: awayScore || (titleMatch ? titleMatch[3] : null),
         display: normalize(scoreWrapper) ||
           (titleMatch ? (titleMatch[2] + '-' + titleMatch[3]) : null)
       }
     };
     if (section.startsWith('player_stats_')) {
       const playerStatsPathMatch = path.match(
         /\/player-stats\/([^/]+)\//
       );
       const playerStatsPathSegment = playerStatsPathMatch
         ? playerStatsPathMatch[1]
         : null;
       const playerStatsPathCategoryMap = {
         top: 'top_stats',
         shots: 'shots',
         attack: 'attack',
         passes: 'passes',
         defense: 'defense',
         defence: 'defense',
         goalkeeping: 'goalkeeping',
         general: 'general'
       };
       const activePlayerStatsCategory = playerStatsPathSegment
         ? (playerStatsPathCategoryMap[playerStatsPathSegment] || null)
         : null;
       const playerStatsCategoryLabels = {
         top_stats: 'Top Stats',
         shots: 'Shots',
         attack: 'Attack',
         passes: 'Passes',
         defense: 'Defense',
         goalkeeping: 'Goalkeeping',
         general: 'General'
       };
       const activePlayerStatsLabel =
         playerStatsCategoryLabels[activePlayerStatsCategory] || null;

       if (activePlayerStatsCategory !== requestedPlayerStatsCategory) {
         throw new Error(
           'Player stats URL mismatch. Expected ' +
           requestedPlayerStatsCategory +
           ', URL category: ' +
           (activePlayerStatsCategory || 'not detected') +
           ', URL: ' +
           location.href
         );
       }
       const headerCandidates = all(document, 'table thead tr th, table thead tr td')
         .map(cell => normalize(text(cell))).filter(Boolean);
       const fieldName = header => {
         const value = (header || '')
           .toLowerCase()
           .replace(/\s+/g, ' ')
           .trim();

         if (value === 'all' || value === 'player') return 'player';
         if (value === 'rating') return 'rating';
         if (value.includes('total shots')) return 'total_shots';
         if (value.includes('expected goals')) return 'expected_goals';

         // More specific pass fields must be checked before accurate_passes.
         if (value.includes('accurate passes in final third'))
           return 'accurate_passes_in_final_third';
         if (value.includes('accurate passes'))
           return 'accurate_passes';

         if (value === 'touches') return 'touches';
         if (value.includes('touches in opposition box'))
           return 'touches_in_opposition_box';
         if (value.includes('successful dribbles'))
           return 'successful_dribbles';

         // Keep the three defensive duel columns separate.
         if (value.includes('aerial duels won'))
           return 'aerial_duels_won';
         if (value.includes('ground duels won'))
           return 'ground_duels_won';
         if (value === 'duels won')
           return 'duels_won';
         if (value === 'duels')
           return 'duels';

         return value
           .replace(/[^a-z0-9]+/g, '_')
           .replace(/^_+|_+$/g, '');
       };
       const parseCellValue = (header, value) => {
         if (value === null || value === undefined || value === '-') return null;
         const key = fieldName(header);
         if (key === 'rating' || key === 'expected_goals') {
           const numberValue = Number(value);
           return Number.isFinite(numberValue) ? numberValue : value;
         }
         if (key === 'total_shots' || key === 'touches' ||
             key === 'touches_in_opposition_box' || key === 'duels') {
           const numberValue = Number(value);
           return Number.isFinite(numberValue) ? numberValue : value;
         }
    
         const normalizedNumber = String(value).replace(',', '.').trim();
         if (/^-?\d+(?:\.\d+)?$/.test(normalizedNumber)) {
           const numberValue = Number(normalizedNumber);
           return Number.isFinite(numberValue) ? numberValue : value;
         }
    
         return value;
       };

       const headerMap = headerCandidates.map((header, index) => ({
         index: index,
         header: header,
         field: fieldName(header)
       }));

       const fieldIndexes = new Map();
       for (const headerItem of headerMap) {
         if (!headerItem.field || headerItem.field === 'player')
           continue;

         if (!fieldIndexes.has(headerItem.field))
           fieldIndexes.set(headerItem.field, []);

         fieldIndexes.get(headerItem.field).push(headerItem.index);
       }

       const headerFieldCollisions = Array.from(fieldIndexes.entries())
         .filter(([, indexes]) => indexes.length > 1)
         .map(([field, indexes]) => ({
           field: field,
           indexes: indexes,
           headers: indexes.map(index => headerCandidates[index])
         }));

       if (headerFieldCollisions.length > 0) {
         throw new Error(
           'Player stats header mapping collision: ' +
           JSON.stringify(headerFieldCollisions)
         );
       }

       const tableRows = all(document, 'table tbody tr').map(row => {
         const cells = all(row, 'th, td')
           .map(cell => normalize(text(cell)))
           .filter(Boolean);

         if (cells.length === 0) return null;

         if (headerCandidates.length > 0 &&
             cells.length !== headerCandidates.length) {
           throw new Error(
             'Player stats row/header length mismatch. Headers: ' +
             headerCandidates.length +
             ', cells: ' +
             cells.length +
             ', row: ' +
             JSON.stringify(cells)
           );
         }
         const playerCell = cells[0] || null;
         const playerPositionPattern =
           /^(.+?)\s+(Central midfielder|Defensive midfielder|Attacking midfielder|Centre back|Center back|Left back|Right back|Left winger|Right winger|Centre forward|Center forward|Second striker|Goalkeeper|Defender|Midfielder|Attacker|Fullback|Wingback|Winger|Striker|Forward)$/i;
         const playerMatch = playerCell
           ? playerCell.match(playerPositionPattern)
           : null;
         const item = {
           player: playerMatch ? playerMatch[1].trim() : playerCell,
           position: playerMatch ? playerMatch[2] : null
         };
         for (let index = 1; index < cells.length; index++) {
           const header = headerCandidates[index] || ('column_' + index);
           const key = fieldName(header);
           if (key && key !== 'player') {
             item[key] = parseCellValue(header, cells[index]);
           }
         }
         item.cells = cells;
         return item;
       }).filter(Boolean);
       const fallbackRows = uniqueTexts(all(document,
         '[data-testid*="player"], [class*="playerStats"], [class*="rating"]')
         .map(row => normalize(text(row))).filter(Boolean));
       result.player_stats = {
         category: requestedPlayerStatsCategory,
         category_label: activePlayerStatsLabel,
         url_category: playerStatsPathSegment,
         source_url: location.href,
         active_tab_label: activePlayerStatsLabel,
         headers: headerCandidates,
         header_map: headerMap,
         header_field_collisions: headerFieldCollisions,
         players: tableRows,
         raw_rows: fallbackRows
       };
       result.extraction_diagnostics = {
         player_stats_category: requestedPlayerStatsCategory,
         category_label: activePlayerStatsLabel,
         url_category: playerStatsPathSegment,
         source_url: location.href,
         active_tab_label: activePlayerStatsLabel,
         player_header_count: headerCandidates.length,
         header_field_collision_count: headerFieldCollisions.length,
         player_table_row_count: tableRows.length,
         player_raw_row_count: fallbackRows.length,
         parsed_player_position_count:
           tableRows.filter(item => item.position !== null).length,
         unknown_player_position_count:
           tableRows.filter(item => item.position === null).length
       };
     }
     return JSON.stringify(result);
     } catch (e) {
       return JSON.stringify({
         extraction_error: String(e && e.stack ? e.stack : e),
         source_url: location.href,
         collected_at_utc: new Date().toISOString()
       });
     }
    })();
    ''';
  Result := StringReplace(
    Result,
    '__PLAYER_STATS_CATEGORY__',
    ACategory,
    [rfReplaceAll]
  );
end;

function BuildCommentaryExtractionScript: string;
begin
  Result := '''
    (() => {
     try {
     const text = e => {
       if (!e) return null;
       const value = (typeof e.innerText === 'string')
         ? e.innerText
         : ((typeof e.textContent === 'string') ? e.textContent : '');
       const trimmed = value.trim();
       return trimmed.length > 0 ? trimmed : null;
     };
     const normalize = value => value ? value.replace(/\s+/g, ' ').trim() : null;
     const all = (root, sel) => Array.from(root.querySelectorAll(sel));
     const firstText = selectors => {
       for (const s of selectors) {
         const value = text(document.querySelector(s));
         if (value) return value;
       }
       return null;
     };
     const uniqueTexts = values => {
       const seen = new Set();
       return values.filter(value => {
         if (!value) return false;
         const key = value.toLowerCase();
         if (seen.has(key)) return false;
         seen.add(key);
         return true;
       });
     };
     const title = document.title || '';
     const titleMatch = title.match(/^(.+?)\s+(\d+)\s*-\s*(\d+)\s+(.+?)\s+\|/);
     const path = location.pathname.toLowerCase();
     let section = 'unknown';
     let statisticPeriod = null;
     if (path.includes('/stats/extra-time/')) {
       section = 'statistics_extra_time';
       statisticPeriod = 'extra_time';
     } else if (path.includes('/stats/1st-half/')) {
       section = 'statistics_first_half';
       statisticPeriod = 'first_half';
     } else if (path.includes('/stats/2nd-half/')) {
       section = 'statistics_second_half';
       statisticPeriod = 'second_half';
     } else if (path.includes('/stats/')) {
       section = 'statistics_overall';
       statisticPeriod = 'overall';
     } else if (path.includes('/lineups/')) section = 'lineups';
     else if (path.includes('/player-stats/')) section = 'player_stats';
     else if (path.includes('/live-commentary/')) section = 'commentary';
     const homeTeam = firstText([
       '.duelParticipant__home .participant__participantName',
       '.duelParticipant__home [class*="participantName"]',
       '[data-testid="wcl-participant-home"]'
     ]);
     const awayTeam = firstText([
       '.duelParticipant__away .participant__participantName',
       '.duelParticipant__away [class*="participantName"]',
       '[data-testid="wcl-participant-away"]'
     ]);
     const homeScore = firstText([
       '.detailScore__wrapper span:first-child',
       '.detailScore__wrapper > div:first-child',
       '[data-testid="wcl-home-score"]'
     ]);
     const awayScore = firstText([
       '.detailScore__wrapper span:last-child',
       '.detailScore__wrapper > div:last-child',
       '[data-testid="wcl-away-score"]'
     ]);
     const scoreWrapper = firstText([
       '.detailScore__wrapper',
       '[data-testid="wcl-detail-score"]'
     ]);
     const competitionText = firstText([
       '.tournamentHeader__country',
       '.tournamentHeader__sportContent',
       '.tournamentHeader__name',
       '[data-testid="wcl-tournament-header"]'
     ]);
     const statusText = firstText([
       '.detailScore__status',
       '[data-testid="wcl-status"]'
     ]);
     const dateTimeText = firstText([
       '.duelParticipant__startTime',
       '[data-testid="wcl-match-info"]'
     ]);
     const result = {
       schema_version: '1.3',
       section: section,
       statistic_period: statisticPeriod,
       source_url: location.href,
       match_id: new URL(location.href).searchParams.get('mid'),
       collected_at_utc: new Date().toISOString(),
       page_title: title || null,
       competition: competitionText || 'WORLD CUP',
       status: statusText,
       date_time: dateTimeText,
       home_team: homeTeam || (titleMatch ? titleMatch[1].trim() : null),
       away_team: awayTeam || (titleMatch ? titleMatch[4].trim() : null),
       score: {
         home: homeScore || (titleMatch ? titleMatch[2] : null),
         away: awayScore || (titleMatch ? titleMatch[3] : null),
         display: normalize(scoreWrapper) ||
           (titleMatch ? (titleMatch[2] + '-' + titleMatch[3]) : null)
       }
     };
     if (section === 'commentary') {
       const rows = all(document,
         '[data-testid*="incident"], .smv__incident, [class*="commentary"]');
       const rawValues = uniqueTexts(rows.map(row => normalize(text(row))).filter(Boolean));
       const values = rawValues
         .filter(value => !/^\d+(?:\+\d+)?'?$/.test(value))
         .filter(value => !/^\d+\s*-\s*\d+$/.test(value))
         .filter(value => !/^\d+(?:\+\d+)?'\s+\d+\s*-\s*\d+$/.test(value));
    
       const parseScore = value => {
         const match = value.match(/^\d+(?:\+\d+)?'\s+(\d+)\s*-\s*(\d+)\b/);
         return match ? {
           home: Number(match[1]),
           away: Number(match[2])
         } : null;
       };
    
       const classifyEvent = value => {
         const lower = value.toLowerCase();
         const tags = [];
         const score = parseScore(value);
         const scoreAtStart = score !== null;
         const disallowedGoal =
           /no goal|disallowed|won't count|will not count|ruled out|offside.*goal/i.test(value);
         const explicitGoal =
           /\bgoal\b/i.test(value) ||
           /own goal|scoresheet|score changes to|the score is|makes it \d+[:\-]\d+/i.test(value) ||
           /back of the net|into the net|past the goalkeeper/i.test(value);
         const periodNarrative =
           /half-time|halftime|end of the first half|end of first half|second half is about to start|full-time|full time|final whistle|blows? (?:his|her|the) whistle/.test(lower);
         const hasGoal = scoreAtStart && !disallowedGoal && !periodNarrative &&
           (explicitGoal || (score.home + score.away) > 0);
    
         const hasVar = /\bvar\b/.test(lower) ||
           /video assistant referee/.test(lower);
         const isPossibleRedCard =
           /could be a red card|possible red card|review(?:ing)?[^.]*red card/.test(lower);
         const hasRedCard =
           !isPossibleRedCard &&
           /produces? a red card|shows?[^.]*red card|receives? a red card|sent off|early shower|deserved red card/.test(lower);
         const hasYellowCard =
           /yellow card|yellow it is|receives the caution|booked|is cautioned|goes into the book|shown a yellow|awards?[^.]*yellow/.test(lower);
         const hasSubstitution =
           /substitution|subsitution|replaced by|comes on|coming on|going off|replacing|replaces|replace\b|in place of/.test(lower);
         const hasAttendance = /attendance/.test(lower);
         const hasPeriod =
           !hasSubstitution &&
           /half-time|halftime|end of the first half|end of first half|second half is about to start|full-time|full time|final whistle|blows? (?:his|her|the) whistle/.test(lower);
    
         if (hasVar) tags.push('var');
         if (hasGoal) tags.push('goal');
         if (hasRedCard) tags.push('red_card');
         if (hasYellowCard) tags.push('yellow_card');
         if (hasSubstitution) tags.push('substitution');
         if (hasAttendance) tags.push('attendance');
         if (hasPeriod) tags.push('period');
    
         let primaryType = 'commentary';
         if (hasGoal) primaryType = 'goal';
         else if (hasRedCard) primaryType = 'red_card';
         else if (hasYellowCard) primaryType = 'yellow_card';
         else if (hasSubstitution) primaryType = 'substitution';
         else if (hasAttendance) primaryType = 'attendance';
         else if (hasPeriod) primaryType = 'period';
         else if (hasVar || isPossibleRedCard) primaryType = 'var_review';
    
         return {
           primary_type: primaryType,
           tags: tags,
           score: score
         };
       };
    
       const parseMinute = value => {
         const match = value.match(/^(\d+)(?:\+(\d+))?'/);
         if (!match) return { minute: null, added_time: null };
         return {
           minute: Number(match[1]),
           added_time: match[2] ? Number(match[2]) : null
         };
       };
    
       const structuredEvents = values.map(value => {
         const minuteInfo = parseMinute(value);
         const classification = classifyEvent(value);
         return {
           type: classification.primary_type,
           primary_type: classification.primary_type,
           tags: classification.tags,
           minute: minuteInfo.minute,
           added_time: minuteInfo.added_time,
           score: classification.score,
           status: 'confirmed',
           text: value
         };
       });
    
       const normalizePersonName = value => (value || '')
         .toLowerCase()
         .replace(/[^a-z0-9]+/g, ' ')
         .trim();
    
       for (let eventIndex = 0;
            eventIndex < structuredEvents.length;
            eventIndex++) {
         const event = structuredEvents[eventIndex];
         const noActionMatch = event.text.match(
           /no action against\s+(.+?)\s*\(/i
         );
    
         if (!noActionMatch || !event.tags.includes('var')) continue;
    
         const personName = normalizePersonName(noActionMatch[1]);
         if (!personName) continue;
    
         for (let previousIndex = eventIndex + 1;
              previousIndex < structuredEvents.length;
              previousIndex++) {
           const previousEvent = structuredEvents[previousIndex];
           if (!previousEvent.tags.includes('yellow_card') &&
               !previousEvent.tags.includes('red_card')) continue;
    
           if (!normalizePersonName(previousEvent.text).includes(personName))
             continue;
    
           previousEvent.status = 'overturned';
           previousEvent.overturned_by_var = true;
           previousEvent.tags = previousEvent.tags.filter(tag =>
             tag !== 'yellow_card' && tag !== 'red_card'
           );
           if (!previousEvent.tags.includes('overturned'))
             previousEvent.tags.push('overturned');
           break;
         }
       }
    
       const hasTag = (item, tag) =>
         item.status !== 'overturned' &&
         Array.isArray(item.tags) &&
         item.tags.includes(tag);
    
       result.commentary = structuredEvents;
       result.events = {
         goals: structuredEvents.filter(item => hasTag(item, 'goal')),
         yellow_cards: structuredEvents.filter(item => hasTag(item, 'yellow_card')),
         red_cards: structuredEvents.filter(item => hasTag(item, 'red_card')),
         substitutions: structuredEvents.filter(item => hasTag(item, 'substitution')),
         var: structuredEvents.filter(item => hasTag(item, 'var')),
         attendance: structuredEvents.filter(item => hasTag(item, 'attendance')),
         periods: structuredEvents.filter(item => hasTag(item, 'period')),
         overturned: structuredEvents.filter(item => item.status === 'overturned')
       };
    
       const expectedGoalCount =
         (Number(result.score.home) || 0) + (Number(result.score.away) || 0);
    
       result.commentary_validation = {
         expected_goal_count_from_score: expectedGoalCount,
         detected_goal_count: result.events.goals.length,
         goal_count_matches_final_score:
           result.events.goals.length === expectedGoalCount,
         score_bearing_event_count:
           structuredEvents.filter(item => item.score !== null).length,
         overturned_event_count: result.events.overturned.length
       };
    
       result.extraction_diagnostics = {
         raw_commentary_row_count: rawValues.length,
         commentary_row_count: structuredEvents.length,
         removed_commentary_noise_count: rawValues.length - values.length,
         goal_event_count: result.events.goals.length,
         yellow_card_event_count: result.events.yellow_cards.length,
         red_card_event_count: result.events.red_cards.length,
         substitution_event_count: result.events.substitutions.length,
         var_event_count: result.events.var.length,
         overturned_event_count: result.events.overturned.length,
         multi_tag_event_count: structuredEvents.filter(item =>
           Array.isArray(item.tags) && item.tags.length > 1).length,
         goal_count_matches_final_score:
           result.events.goals.length === expectedGoalCount,
         commentary_event_validation: {
           expected_goal_count_from_score: expectedGoalCount,
           detected_goal_count: result.events.goals.length
         }
       };
     }
     return JSON.stringify(result);
     } catch (e) {
       return JSON.stringify({
         extraction_error: String(e && e.stack ? e.stack : e),
         source_url: location.href,
         collected_at_utc: new Date().toISOString()
       });
     }
    })();
    ''';
end;

function BuildMatchDiscoveryScript(const AArchive2022: Boolean): string;
begin
  Result := '''
    (() => {
     try {
       const normalize = value => (value || '').replace(/\s+/g, ' ').trim();
       const archive2022 = __ARCHIVE_2022__;
       const archiveMatchLimit = 64;
       const seen = new Set();
       const matches = [];
       const eventNodes = Array.from(document.querySelectorAll('[id^="g_"]'));
       const findStageText = eventNode => {
         let cursor = eventNode ? eventNode.previousElementSibling : null;
         let inspected = 0;
         while (cursor && inspected < 250) {
           const className = String(cursor.className || '').toLowerCase();
           if (className.includes('event__round') ||
               className.includes('event__title')) {
             const label = normalize(cursor.innerText || cursor.textContent);
             if (label) return label;
           }
           cursor = cursor.previousElementSibling;
           inspected++;
         }
         return '';
       };
       const addMatch = (matchId, href, text, eventNode) => {
         if (!matchId || seen.has(matchId)) return;
         if (archive2022 && matches.length >= archiveMatchLimit) return;
         let cleanUrl = (href || '').split('#')[0].split('?')[0];
         cleanUrl = cleanUrl.replace(/\/+$/, '');
         if (!cleanUrl.includes('/match/')) return;
         seen.add(matchId);
         const url = cleanUrl + '/summary/stats/overall/?mid=' + matchId;
         matches.push({
           match_id: matchId,
           url: url,
           text: normalize(text),
           stage: findStageText(eventNode),
           dom_order: matches.length
         });
       };
       for (const eventNode of eventNodes) {
         if (archive2022 && matches.length >= archiveMatchLimit) break;
         const idMatch = (eventNode.id || '').match(/_([A-Za-z0-9]{8})$/);
         const anchor = eventNode.querySelector('a[href*="/match/"]');
         if (!idMatch || !anchor) continue;
         addMatch(idMatch[1], anchor.href, eventNode.innerText, eventNode);
       }
       const anchors = Array.from(document.querySelectorAll('a[href*="/match/"]'));
       if (!archive2022 || matches.length < archiveMatchLimit) {
         for (const anchor of anchors) {
           if (archive2022 && matches.length >= archiveMatchLimit) break;
           const href = anchor.href || '';
           const eventNode = anchor.closest('[id^="g_"]');
           let matchId = '';
           const queryMatch = href.match(/[?&]mid=([A-Za-z0-9]+)/i);
           if (queryMatch) matchId = queryMatch[1];
           if (!matchId) {
             const idMatch = eventNode ?
               (eventNode.id || '').match(/_([A-Za-z0-9]{8})$/) : null;
             if (idMatch) matchId = idMatch[1];
           }
           const container = eventNode || anchor;
           addMatch(matchId, href, container.innerText, eventNode);
         }
       }
       let loadMoreClicked = false;
       if (!archive2022 || matches.length < archiveMatchLimit) {
         const moreCandidates = Array.from(document.querySelectorAll(
           '.event__more, [class*="event__more"], button, a'
         ));
         const showMore = moreCandidates.find(node => {
           const label = normalize(node.innerText || node.textContent).toLowerCase();
           const visible = !!(node.offsetWidth || node.offsetHeight || node.getClientRects().length);
           return visible && (label === 'show more' || label.includes('show more'));
         });
         if (showMore) {
           showMore.click();
           loadMoreClicked = true;
         }
       }
       return JSON.stringify({
         section: 'match_discovery',
         page_url: location.href,
         page_title: document.title,
         body_text_length: (document.body && document.body.innerText || '').length,
         event_node_count: eventNodes.length,
         anchor_count: anchors.length,
         match_count: matches.length,
         final_tournament_limit: archive2022 ? archiveMatchLimit : 0,
         load_more_clicked: loadMoreClicked,
         matches: matches
       });
     } catch (error) {
       return JSON.stringify({
         section: 'match_discovery',
         extraction_error: String(error && error.stack ? error.stack : error)
       });
     }
    })()
    ''';

  if AArchive2022 then
    Result := StringReplace(Result, '__ARCHIVE_2022__', 'true', [rfReplaceAll])
  else
    Result := StringReplace(Result, '__ARCHIVE_2022__', 'false', [rfReplaceAll]);
end;


end.
