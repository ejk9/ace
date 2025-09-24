# League of Legends Game Data Deployment Guide

This guide covers the automated deployment and population of League of Legends champion and skin data for the ACE draft tool.

## Overview

The system provides automated tools to populate your database with:
- **Champions**: Basic champion data (names, roles, titles, difficulty)
- **Champion Skins**: Splash art variations with skin names and metadata
- **Automated Updates**: Scripts for keeping data current with new patches

## Quick Start

### Full Deployment Setup
```bash
# Complete setup - champions + skins with latest patch (FULLY AUTOMATED)
mix setup_game_data

# Setup with specific patch version (optional)
mix setup_game_data --patch=15.18.1

# Force update existing data to latest patch
mix setup_game_data --force-update
```

**🎯 Zero Configuration Required**: The system automatically fetches the latest patch version from `https://ddragon.leagueoflegends.com/api/versions.json` and champion data from `https://ddragon.leagueoflegends.com/cdn/{latest_patch}/data/en_US/champion.json` without any manual patch configuration needed.

### Individual Components
```bash
# Champions only (automatically uses latest patch)
mix populate_champions

# Skins only (requires champions to exist)
mix populate_skins

# Champions with specific patch (optional override)
mix populate_champions --patch=15.18.1

# Update existing champions to latest patch
mix populate_champions --force-update

# Update skins for specific champion
mix populate_skins --champion-id=103 --force-update
```

## Data Sources

### Data Dragon (Riot Games Official)
- **Source**: `https://ddragon.leagueoflegends.com`
- **Content**: Champion metadata, roles, difficulty, titles
- **Update Frequency**: Updated manually by Riot after each patch
- **Usage**: Primary source for champion basic data

### Community Dragon
- **Source**: `https://cdn.communitydragon.org`
- **Content**: High-quality splash art, skin variations, enhanced assets
- **Update Frequency**: Community-maintained, updated frequently
- **Usage**: Splash art URLs and skin data

## Database Schema

### Champions Table
```sql
CREATE TABLE champions (
  id SERIAL PRIMARY KEY,
  name VARCHAR NOT NULL,
  key VARCHAR UNIQUE NOT NULL,
  title VARCHAR NOT NULL,
  image_url VARCHAR NOT NULL,
  roles VARCHAR[] NOT NULL,
  tags VARCHAR[] NOT NULL,
  difficulty INTEGER NOT NULL,
  enabled BOOLEAN DEFAULT FALSE,
  release_date DATE,
  inserted_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

### Champion Skins Table
```sql
CREATE TABLE champion_skins (
  id SERIAL PRIMARY KEY,
  champion_id INTEGER REFERENCES champions(id) ON DELETE CASCADE,
  skin_id INTEGER NOT NULL,
  name VARCHAR NOT NULL,
  splash_url VARCHAR NOT NULL,
  loading_url VARCHAR,
  tile_url VARCHAR,
  rarity VARCHAR,
  cost INTEGER,
  release_date DATE,
  enabled BOOLEAN DEFAULT TRUE,
  chromas JSONB DEFAULT '[]',
  inserted_at TIMESTAMP,
  updated_at TIMESTAMP,
  UNIQUE(champion_id, skin_id)
);
```

## URL Formats

### Champion Splash Art
```
Default: https://cdn.communitydragon.org/latest/champion/{championId}/splash-art/centered
Skins:   https://cdn.communitydragon.org/latest/champion/{championId}/splash-art/centered/skin/{skinId}
```

### Additional Assets
```
Loading Screen: https://cdn.communitydragon.org/latest/champion/{championId}/splash-art/skin/{skinId}
Tile Images:    https://cdn.communitydragon.org/latest/champion/{championId}/tile/skin/{skinId}
```

## Production Deployment

### Docker Deployment
```dockerfile
# In your Dockerfile, add after database setup:
RUN mix setup_game_data --skip-migration
```

### Manual Deployment
```bash
# 1. Run migrations
mix ecto.migrate

# 2. Populate game data
mix setup_game_data --skip-migration

# 3. Verify setup
mix run -e "IO.inspect(AceApp.LoL.get_champion_stats())"
mix run -e "IO.inspect(AceApp.LoL.get_skin_stats())"
```

### Automated CI/CD
```yaml
# Example GitHub Actions step
- name: Setup Game Data
  run: |
    mix ecto.migrate
    mix setup_game_data --skip-migration
  env:
    DATABASE_URL: ${{ secrets.DATABASE_URL }}
```

## Updating for New Patches

### Automatic Updates
```bash
# Update to latest patch (automatically detects and uses latest version)
mix setup_game_data --force-update

# Update to specific patch (manual override)
mix setup_game_data --patch=15.19.1 --force-update
```

**✨ Current Live Data**: As of testing, the system automatically detects patch `15.18.1` with `171 champions` available.

### Scheduled Updates
```bash
# Weekly cron job example
0 2 * * 1 cd /app && mix setup_game_data --force-update
```

## Error Handling

### Common Issues

**Network Timeouts**
```bash
# Increase timeout and retry
mix setup_game_data --force-update
```

**Missing Champions**
```bash
# Verify champion population first
mix populate_champions --force-update
mix populate_skins --force-update
```

**Data Validation Errors**
```bash
# Check individual champion
mix run -e "AceApp.LoL.get_champion_by_name('Ahri') |> IO.inspect()"
```

### Debugging
```bash
# Enable detailed logging
MIX_ENV=dev mix setup_game_data --force-update

# Check specific champion data
mix run -e "AceApp.LoL.list_champion_skins(1) |> IO.inspect()"

# Verify database state
mix run -e "AceApp.LoL.get_champion_stats() |> IO.inspect()"
mix run -e "AceApp.LoL.get_skin_stats() |> IO.inspect()"
```

## Integration with Draft System

### Champion Selection
The system automatically selects from enabled champions:
```elixir
# In your draft logic
champions = AceApp.LoL.list_enabled_champions()
random_champion = Enum.random(champions)
```

### Skin Splash Art Display
Champion picks automatically show random skin variations:
```elixir
# Popup system picks random skin for visual variety
skin = AceApp.LoL.get_random_champion_skin(champion.id)
splash_url = if skin, do: skin.splash_url, else: champion.image_url
```

### Champion Search and Filtering
```elixir
# Search functionality
champions = AceApp.LoL.search_champions("yasuo")

# Filter by role
champions = AceApp.LoL.list_champions_by_role(:mid)
```

## Performance Considerations

### Initial Population
- Champions: ~160 champions (~30 seconds)
- Skins: ~1000+ skins (~5-10 minutes)
- Total deployment time: ~10-15 minutes

### Memory Usage
- Champion data: ~50KB per champion
- Skin data: ~100KB per skin
- Total database size: ~10-20MB for complete dataset

### Caching Strategy
```elixir
# Champions are cached in application memory
champions = AceApp.LoL.list_enabled_champions()  # Cached result

# Skins loaded on-demand
skins = AceApp.LoL.list_champion_skins(champion_id)  # Database query
```

## Monitoring and Maintenance

### Health Checks
```bash
# Verify champion count
mix run -e "stats = AceApp.LoL.get_champion_stats(); IO.puts('Champions: #{stats.enabled}/#{stats.total}')"

# Verify skin coverage
mix run -e "stats = AceApp.LoL.get_skin_stats(); IO.puts('Skins: #{stats.enabled_skins} across #{stats.champions_with_skins} champions')"
```

### Data Integrity
```bash
# Check for missing associations
mix run -e "AceApp.Repo.query!('SELECT COUNT(*) FROM picks WHERE champion_id NOT IN (SELECT id FROM champions)') |> IO.inspect()"

# Verify splash art URLs
mix run -e "champions = AceApp.LoL.list_enabled_champions(); Enum.each(champions, fn c -> IO.puts('#{c.name}: #{c.image_url}') end)"
```

## Support and Troubleshooting

### Common Solutions
1. **Empty champion list**: Run `mix populate_champions --force-update`
2. **Missing splash art**: Run `mix populate_skins --force-update`
3. **Outdated data**: Run `mix setup_game_data --force-update`
4. **Network issues**: Check firewall settings for external API access

### Log Analysis
```bash
# Check recent deployment logs
grep "Champion population" /var/log/app.log
grep "Skin population" /var/log/app.log
```

For additional support, check the application logs and verify network connectivity to:
- `ddragon.leagueoflegends.com`
- `cdn.communitydragon.org`
- `raw.communitydragon.org`