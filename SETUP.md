# Sådan sætter du Haulwise op med fælles data

## Status (17/11-2026)
- ✅ Supabase: organisation **Haulwise** (Free), projekt `njpkpiufvdrwuhlhwvof` (eu-west-1)
- ✅ Database (001), natlig opdatering (pg_cron 03:17 UTC), upload-funktion `bright-handler` (vist som "submit"), `COFFER_SALT` sat
- ✅ Testet live: upload → samling → udtræk → addonet læser det
- ⬜ Kontakt-e-mail på upload-siden (`docs/index.html`, `CONTACT_EMAIL`)
- ⬜ GitHub-repo + GitHub Pages (upload-siden) + variabler
- ⬜ CurseForge-projekt
- ⬜ Test i spillet + screenshots

Værdier (offentlige, må gerne stå her):
- `SUPABASE_URL` = `https://njpkpiufvdrwuhlhwvof.supabase.co`
- `SUPABASE_PUBLISHABLE_KEY` = `sb_publishable_kmTESVC8h-492aAnqZK0NA_s1DUZ605`
- Upload-adresse: `https://njpkpiufvdrwuhlhwvof.supabase.co/functions/v1/bright-handler`


Alt herunder er gratis og helt adskilt fra CPH3D. Det tager cirka en time første gang.

Dele:
- **Supabase** (privat konto): database og upload-endpoint.
- **GitHub** (privat konto): koden, hjemmesiden (GitHub Pages) og automatiske releases.
- **CurseForge**: der hvor spillerne henter addonet.

> Ingen nøgler eller passwords skal ind i koden eller i chatten. Den eneste nøgle, der står i koden, er Supabase's *publishable key*, og den er lavet til at være offentlig. Den kan kun læse de to offentlige funktioner.

---

## 1. Supabase

1. Gå til supabase.com og **opret en ny konto med en privat e-mail** (ikke din firma-login).
2. Opret en organisation, fx `Haulwise`, på **Free**-planen. Opret et projekt `haulwise` i region **Central EU (Frankfurt)**. Gem database-passwordet i din password manager.
3. **SQL Editor → New query**: indsæt hele `supabase/migrations/001_coffer.sql` og tryk **Run**.
4. **Database → Extensions**: søg efter `pg_cron` og slå den til. Kør derefter `supabase/migrations/002_schedule.sql` i SQL Editor. Den bygger de fælles data hver nat kl. 04:17 dansk tid.
5. Upload-funktionen deployes fra din computer i en terminal, i den mappe hvor repoet ligger:
   ```
   npx supabase login
   npx supabase link --project-ref DIT-PROJECT-REF
   npx supabase functions deploy submit --no-verify-jwt --use-api
   npx supabase secrets set COFFER_SALT=$(openssl rand -hex 32)
   ```
   Dit project ref er bogstaverne i projektets URL: `https://DIT-PROJECT-REF.supabase.co`.
   `COFFER_SALT` må aldrig ændres bagefter, for så kan en spillers nye upload ikke længere erstatte den gamle.
6. **Project Settings → API Keys**: kopiér **Project URL** og **Publishable key** (`sb_publishable_...`). Du skal bruge dem i trin 2 og 3.

> Free-projekter pauser efter en uge uden aktivitet. Uploads og den ugentlige data-opdatering holder det i gang. Hvis det alligevel pauser, kan du vække det med ét klik i dashboardet.

## 2. Hjemmesiden

1. Åbn `docs/index.html` og udfyld de tre linjer øverst i `<script>`: `SUPABASE_URL`, `PUBLISHABLE_KEY` og `CONTACT_EMAIL`. Brug en privat e-mail, så folk kan bede om at få deres data slettet (det kræver GDPR).
2. Den bliver lagt online i trin 3 via GitHub Pages, gratis på `kaayceegamer.github.io/haulwise`.

## 3. GitHub

1. Opret en **offentlig** repository `haulwise` på din private GitHub-konto. Koden skal være synlig, for det kræver Blizzards addon-regler.
2. Push hele mappen:
   ```
   git init && git add . && git commit -m "Haulwise 0.3.0"
   git branch -M main
   git remote add origin https://github.com/KaayceeGamer/haulwise.git
   git push -u origin main
   ```
3. **Settings → Pages**: Source = *Deploy from a branch*, Branch = `main`, mappe = `/docs`.
4. **Settings → Secrets and variables → Actions**:
   - under *Variables*: `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` og `CURSEFORGE_PROJECT_ID` (det sidste får du i trin 4)
   - under *Secrets*: `CF_API_KEY` (fra trin 4)

## 4. CurseForge

1. Lav en konto på curseforge.com og gå til **authors.curseforge.com → Create Project**. Vælg World of Warcraft og Addons, navngiv det Haulwise og skriv beskrivelsen (du kan bruge README.md). Godkendelse tager normalt et døgn.
2. Når projektet er godkendt: kopiér **Project ID** (tallet i sidebaren, ikke navnet i URL'en) til variablen `CURSEFORGE_PROJECT_ID`.
3. **authors.curseforge.com → API tokens**: lav en token og læg den i secret'en `CF_API_KEY`.

## 5. Udgiv

```
git tag v0.3.0
git push --tags
```
GitHub bygger zip-filen og uploader den til CurseForge (se fanen *Actions*).

Bagefter kører det af sig selv. **Hver onsdag** henter workflowet *Community data* den nyeste fælles data ind i `Data.lua`. Hvis der er nyt, udgives en ny version (fx `v0.3.0-data20261125`), så alle spillere får den større datapulje via CurseForge-appen.

---

## Før du udgiver offentligt

Addonet er kun testet uden for spillet mod en efterlignet udgave af WoW's API. Test det selv i spillet først:
- [ ] `/haul` åbner vinduet, og alle fem faner virker
- [ ] Kills tæller, når du looter (og tomme lig efter 2 sekunder)
- [ ] Skinning og pickpocket bliver registreret
- [ ] **Scan AH** virker, og der kommer priser
- [ ] Profession-vinduer bliver læst (Craft-fanen fyldes)
- [ ] `/haul export` → upload på hjemmesiden → "Thanks!"
- [ ] Kør `select refresh_community();` i SQL Editor, og "Copy community data" virker → `/haul import`
- [ ] `/haul debug` viser ingen fejl

## Drift

- **Slet en spillers data** (GDPR): de sender deres export-streng. Id'et er det andet felt (`CF1,DETTE-ID,...`). I SQL Editor:
  ```sql
  delete from contributors
  where uid_hash = encode(sha256(convert_to('DETTE-ID|' || 'DIT-COFFER_SALT', 'utf8')), 'hex');
  ```
- **Byg fællesdata med det samme:** `select refresh_community();`
- **Se status:** `select * from community_meta;` (`excluded` er antal frasorterede mistænkelige uploads)
- **Tests:** `cd tests && npm install && cd .. && node --experimental-strip-types tests/server.test.ts` og `python3 tests/run.py "$PWD" "$PWD/tests"` (kræver `pip install lupa`). De kører også automatisk på GitHub ved hvert push.
