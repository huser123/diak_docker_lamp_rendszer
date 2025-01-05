
# Diák Docker Környezet

Ez a projekt egy egyszerű Docker-alapú környezetet biztosít diákok számára, ahol minden diák saját PHP, MySQL és FTP konténert kap. A rendszer automatikusan kezeli a konfigurációkat és a konténereket, valamint egy Traefik proxy biztosítja az aldomain alapú hozzáférést.

## Főbb jellemzők

- **Személyre szabott környezet**: Minden diák saját aldomainnel, PHP szerverrel, MySQL adatbázissal és FTP hozzáféréssel rendelkezik.
- **Automatikus beállítások**: A szükséges fájlok, könyvtárak és konfigurációk generálása automatikus.
- **Traefik integráció**: A rendszer Traefik proxy-t használ az aldomain-ek kezelésére.
- **Egyszerűen bővíthető**: Új diák hozzáadása gyors és könnyű.

## Használati utasítás

### 1. Szükséges eszközök

Győződj meg arról, hogy az alábbi eszközök telepítve vannak:
- Docker
- Docker Compose

### 2. Projekt klónozása

Klónozd ezt a repót a saját gépedre:
```bash
git clone <repo-url>
cd <repo-folder>
```

### 3. Környezet beállítása

A `setup.sh` futtatásával automatikusan létrejönnek a szükséges fájlok és konténerek:
```bash
sudo ./setup.sh
```

### 4. Hosts fájl frissítése

A diákok aldomainjeit hozzá kell adnod a hosts fájlhoz, például:
```
127.0.0.1 kalmanpeter.teszt.hu nagyadam.teszt.hu szepanna.teszt.hu
...
```

### 5. Elérés

A diákok saját környezete az alábbi URL-eken érhető el:
- [http://kalmanpeter.teszt.hu](http://kalmanpeter.teszt.hu)
- [http://nagyadam.teszt.hu](http://nagyadam.teszt.hu)
- ...

### 6. Konténerek kezelése

A konténerek elindítása, újraindítása vagy leállítása:
- **Indítás**: `docker compose up -d`
- **Leállítás**: `docker compose down`

### 7. Új diák hozzáadása

A `setup.sh` automatikusan létrehozza a szükséges fájlokat és konténereket új diákok számára. Frissítsd a diákok listáját a `setup.sh` belsejében, majd futtasd újra a szkriptet:
```bash
sudo ./setup.sh
```

## Fontos megjegyzések

- A környezet elsősorban helyi tesztelésre készült.
- Az FTP jelszavak és adatbázisok alapértelmezett jelszavai a diákok neve alapján generálódnak.
- A rendszer dinamikusan bővíthető új diákok hozzáadásával.
