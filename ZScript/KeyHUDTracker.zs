// Standalone Key HUD Tracker Mod for GZDoom / UZDoom
// Ported mathematical projection formulas from libeye by KeksDose

class KHT_ProjScreen ui {
    protected vector2 resolution;
    protected vector2 origin;
    protected vector2 tan_fov_2;
    protected double pixel_stretch;
    protected double aspect_ratio;

    protected vector3 view_ang;
    protected vector3 view_pos;
    protected double depth;
    protected vector2 proj_pos;
    protected vector3 diff;

    void CacheResolution() {
        CacheCustomResolution((Screen.GetWidth(), Screen.GetHeight()));
    }

    void CacheCustomResolution(vector2 new_resolution) {
        resolution = new_resolution;
        pixel_stretch = level.pixelstretch;
        aspect_ratio = max(4.0 / 3, Screen.GetAspectRatio());
    }

    double AspectRatio() const {
        return aspect_ratio;
    }

    void CacheFov(double hor_fov = 90) {
        tan_fov_2.x = tan(hor_fov / 2) * aspect_ratio / (4.0 / 3);
        tan_fov_2.y = tan_fov_2.x / aspect_ratio;
    }

    ui void OrientForRenderOverlay(RenderEvent event) {
        Reorient(event.viewpos, (event.viewangle, event.viewpitch, event.viewroll));
    }

    void OrientForPlayer(PlayerInfo player) {
        Reorient(player.mo.vec3offset(0, 0, player.viewheight), (player.mo.angle, player.mo.pitch, player.mo.roll));
    }

    virtual void Reorient(vector3 world_view_pos, world_ang) {
        view_ang = world_ang;
        view_pos = world_view_pos;
    }

    virtual void BeginProjection() {}
    virtual void ProjectWorldPos(vector3 world_pos) {}
    virtual vector2 ProjectToNormal() const { return (0, 0); }
    virtual vector2 ProjectToScreen() const { return (0, 0); }

    virtual vector2 ProjectToCustom(vector2 origin, vector2 resolution) const {
        return (0, 0);
    }

    bool IsInFront() const {
        return 0 < depth;
    }

    bool IsInScreen() const {
        if (proj_pos.x < -depth || depth < proj_pos.x || proj_pos.y < -depth || depth < proj_pos.y) {
            return false;
        }
        return true;
    }

    virtual void BeginDeprojection() {}
    virtual vector3 DeprojectNormalToDiff(vector2 normal_pos, double depth = 1) const { return (0, 0, 0); }
    virtual vector3 DeprojectScreenToDiff(vector2 screen_pos, double depth = 1) const { return (0, 0, 0); }
    virtual vector3 DeprojectCustomToDiff(vector2 origin, vector2 resolution, vector2 screen_pos, double depth = 1) const { return (0, 0, 0); }

    vector2 NormalToScreen(vector2 normal_pos) const {
        normal_pos = 0.5 * (normal_pos + (1, 1));
        return (normal_pos.x * resolution.x, normal_pos.y * resolution.y);
    }

    vector2 ScreenToNormal(vector2 screen_pos) const {
        screen_pos = (screen_pos.x / resolution.x, screen_pos.y / resolution.y);
        return 2 * screen_pos - (1, 1);
    }

    vector3 Difference() const { return diff; }
    double Distance() const { return diff.length(); }
}

class KHT_GlScreen : KHT_ProjScreen {
    protected vector3 forw_unit;
    protected vector3 right_unit;
    protected vector3 down_unit;

    override void Reorient(vector3 world_view_pos, vector3 world_ang) {
        world_ang.y = VectorAngle(cos(world_ang.y), sin(world_ang.y) * pixel_stretch);
        super.Reorient(world_view_pos, world_ang);

        let cosang  = cos(world_ang.x);
        let cosvang = cos(world_ang.y);
        let cosrang = cos(world_ang.z);
        let sinang  = sin(world_ang.x);
        let sinvang = sin(world_ang.y);
        let sinrang = sin(world_ang.z);

        let right_no_roll = (sinang, -cosang, 0);
        let down_no_roll  = (-sinvang * cosang, -sinvang * sinang, -cosvang);

        forw_unit = (cosvang * cosang, cosvang * sinang, -sinvang);
        down_unit  = cosrang * down_no_roll  - sinrang * right_no_roll;
        right_unit = cosrang * right_no_roll + sinrang * down_no_roll;
    }

    protected vector3 forw_in;
    protected vector3 right_in;
    protected vector3 down_in;

    override void BeginProjection() {
        forw_in  = forw_unit;
        right_in = right_unit / tan_fov_2.x;
        down_in  = down_unit  / tan_fov_2.y;

        forw_in.z  *= pixel_stretch;
        right_in.z *= pixel_stretch;
        down_in.z  *= pixel_stretch;
    }

    override void ProjectWorldPos(vector3 world_pos) {
        diff     = levellocals.vec3diff(view_pos, world_pos);
        proj_pos = (diff dot right_in, diff dot down_in);
        depth    = diff dot forw_in;
    }

    override vector2 ProjectToNormal() const {
        return proj_pos / depth;
    }

    override vector2 ProjectToScreen() const {
        let normal_pos = proj_pos / depth + (1, 1);
        return 0.5 * (normal_pos.x * resolution.x, normal_pos.y * resolution.y);
    }

    override vector2 ProjectToCustom(vector2 origin, vector2 resolution) const {
        let normal_pos = proj_pos / depth + (1, 1);
        return origin + 0.5 * (normal_pos.x * resolution.x, normal_pos.y * resolution.y);
    }

    protected vector3 forw_out;
    protected vector3 right_out;
    protected vector3 down_out;

    override void BeginDeprojection() {
        forw_out  = forw_unit;
        right_out = right_unit * tan_fov_2.x;
        down_out  = down_unit  * tan_fov_2.y;

        forw_out.z  /= pixel_stretch;
        right_out.z /= pixel_stretch;
        down_out.z  /= pixel_stretch;
    }

    override vector3 DeprojectNormalToDiff(vector2 normal_pos, double depth) const {
        return depth * (forw_out + normal_pos.x * right_out + normal_pos.y * down_out);
    }

    override vector3 DeprojectScreenToDiff(vector2 screen_pos, double depth) const {
        let normal_pos = 2 * (screen_pos.x / resolution.x, screen_pos.y / resolution.y) - (1, 1);
        return depth * (forw_out + normal_pos.x * right_out + normal_pos.y * down_out);
    }
}

class KHT_SwScreen : KHT_ProjScreen {
    protected vector2 right_planar_unit;
    protected vector3 forw_planar_unit;

    override void Reorient(vector3 world_view_pos, vector3 world_ang) {
        super.Reorient(world_view_pos, world_ang);

        right_planar_unit = (sin(view_ang.x), -cos(view_ang.x));
        forw_planar_unit = (-right_planar_unit.y, right_planar_unit.x, tan(view_ang.y));
    }

    protected vector3 forw_planar_in;
    protected vector2 right_planar_in;

    override void BeginProjection() {
        right_planar_in = right_planar_unit / tan_fov_2.x;
        forw_planar_in  = forw_planar_unit;
    }

    override void ProjectWorldPos(vector3 world_pos) {
        diff    = levellocals.vec3diff(view_pos, world_pos);
        depth   = forw_planar_in.xy dot diff.xy;
        diff.z  += forw_planar_in.z * depth;
        proj_pos = (right_planar_in dot diff.xy, -pixel_stretch * diff.z / tan_fov_2.y);
    }

    override vector2 ProjectToNormal() const {
        return proj_pos / depth;
    }

    override vector2 ProjectToScreen() const {
        let normal_pos = proj_pos / depth + (1, 1);
        return 0.5 * (normal_pos.x * resolution.x, normal_pos.y * resolution.y);
    }

    override vector2 ProjectToCustom(vector2 origin, vector2 resolution) const {
        let normal_pos = proj_pos / depth + (1, 1);
        return origin + 0.5 * (normal_pos.x * resolution.x, normal_pos.y * resolution.y);
    }

    protected vector3 forw_planar_out;
    protected vector3 right_planar_out;
    protected vector3 down_planar_out;

    override void BeginDeprojection() {
        forw_planar_out.xy  = forw_planar_unit.xy;
        forw_planar_out.z   = 0;
        right_planar_out.xy = tan_fov_2.x * right_planar_unit;
        right_planar_out.z  = 0;
        down_planar_out     = (0, 0, tan_fov_2.y / pixel_stretch);
    }

    override vector3 DeprojectNormalToDiff(vector2 normal_pos, double depth) const {
        return depth * (forw_planar_out + normal_pos.x * right_planar_out - (0, 0, forw_planar_unit.z) - normal_pos.y * down_planar_out);
    }

    override vector3 DeprojectScreenToDiff(vector2 screen_pos, double depth) const {
        let normal_pos = 2 * (screen_pos.x / resolution.x, screen_pos.y / resolution.y) - (1, 1);
        return depth * (forw_planar_out + normal_pos.x * right_planar_out - (0, 0, forw_planar_unit.z) - normal_pos.y * down_planar_out);
    }
}

struct KHT_Viewport {
    private vector2 scene_origin;
    private vector2 scene_size;
    private vector2 viewport_origin;
    private vector2 viewport_bound;
    private vector2 viewport_size;
    private double scene_aspect;
    private double viewport_aspect;
    private double scale_f;
    private vector2 scene_to_viewport;

    ui void FromHud() const {
        scene_aspect = Screen.GetAspectRatio();
        vector2 hud_origin;
        vector2 hud_size;
        [hud_origin.x, hud_origin.y, hud_size.x, hud_size.y] = Screen.GetViewWindow();
        let window_resolution = (Screen.GetWidth(), Screen.GetHeight());
        let window_to_normal = (1.0 / window_resolution.x, 1.0 / window_resolution.y);
        viewport_origin = (window_to_normal.x * hud_origin.x, window_to_normal.y * hud_origin.y);
        viewport_size = (window_to_normal.x * hud_size.x, window_to_normal.y * hud_size.y);
        viewport_aspect = hud_size.x / hud_size.y;
        viewport_bound = viewport_origin + viewport_size;

        let statusbar_height = (window_resolution.y - Statusbar.GetTopOfStatusbar()) / window_resolution.y;
        scale_f = hud_size.x / window_resolution.x;
        scene_size = (scale_f, scale_f);
        scene_origin = viewport_origin - (0, 0.5 * (scene_size.y - viewport_size.y));
        scene_to_viewport = (viewport_size.x / scene_size.x, viewport_size.y / scene_size.y);
    }

    bool IsInside(vector2 scene_pos) const {
        let normal_pos = scene_origin + (scene_size.x * 0.5 * (1 + scene_pos.x), scene_size.y * 0.5 * (1 + scene_pos.y));
        if (normal_pos.x < viewport_origin.x || viewport_bound.x < normal_pos.x ||
            normal_pos.y < viewport_origin.y || viewport_bound.y < normal_pos.y) {
            return false;
        }
        return true;
    }

    vector2 SceneToCustom(vector2 scene_pos, vector2 resolution) const {
        let normal_pos = 0.5 * ((scene_pos.x + 1) * scene_size.x, (scene_pos.y + 1) * scene_size.y);
        return ((scene_origin.x + normal_pos.x) * resolution.x, (scene_origin.y + normal_pos.y) * resolution.y);
    }

    vector2 SceneToWindow(vector2 scene_pos) const {
        return SceneToCustom(scene_pos, (Screen.GetWidth(), Screen.GetHeight()));
    }

    vector2 ViewportToCustom(vector2 viewport_pos, vector2 resolution) const {
        let normal_pos = 0.5 * ((viewport_pos.x + 1) * viewport_size.x, (viewport_pos.y + 1) * viewport_size.y);
        return ((viewport_origin.x + normal_pos.x) * resolution.x, (viewport_origin.y + normal_pos.y) * resolution.y);
    }

    vector2 ViewportToWindow(vector2 viewport_pos) const {
        return ViewportToCustom(viewport_pos, (Screen.GetWidth(), Screen.GetHeight()));
    }

    double Scale() const {
        return scale_f;
    }
}

class KeyHUDTrackerHandler : StaticEventHandler {
    private ui bool isInitialized;
    private ui bool isPrepared;
    private ui CVar cvarRenderer;
    private ui CVar cv_track_weapons;
    private ui KHT_ProjScreen projection;
    private ui KHT_GlScreen glProjection;
    private ui KHT_SwScreen swProjection;

    private ui CVar cv_enabled;
    private ui CVar cv_scale;
    private ui CVar cv_alpha;
    private ui CVar cv_show_distance;
    private ui CVar cv_max_distance;
    private ui CVar cv_track_exits;
    private ui CVar cv_track_entry;
    private ui CVar cv_track_secrets;

    // Shifted from 'ui' to play scope so they properly serialize and sync on Quickloads
    private Array<double> exitPositionsX;
    private Array<double> exitPositionsY;
    private Array<double> exitPositionsZ;
    private Array<int> exitSpecials;
    private Array<int> secretSectors;

    private Vector3 playEntryPos;
    private bool playEntryPosValid;

    private SpriteID spr_ykey, spr_bkey, spr_rkey, spr_gkey, spr_skey, spr_gold, spr_silv, spr_tnt1;

    private Array<Actor> keysInLevel;
    private Array<Actor> secretActors;

    private ui void InitCVars() {
        PlayerInfo player = players[consoleplayer];
        if (!player || cv_enabled) return;

        cv_enabled = CVar.GetCVar("key_tracker_enabled", player);
        cv_scale = CVar.GetCVar("key_tracker_scale", player);
        cv_alpha = CVar.GetCVar("key_tracker_alpha", player);
        cv_show_distance = CVar.GetCVar("key_tracker_show_distance", player);
        cv_max_distance = CVar.GetCVar("key_tracker_max_distance", player);
        cv_track_weapons = CVar.GetCVar("key_tracker_track_weapons", player);
        cv_track_exits = CVar.GetCVar("key_tracker_track_exits", player);
        cv_track_entry = CVar.GetCVar("key_tracker_track_entry", player);
        cv_track_secrets = CVar.GetCVar("key_tracker_track_secrets", player);
        cvarRenderer = CVar.GetCVar("vid_rendermode", player);
    }

    private ui void InitializeProjection() {
        glProjection = new("KHT_GlScreen");
        swProjection = new("KHT_SwScreen");
        isInitialized = true;
    }

    private ui void PrepareProjection() {
        if (cvarRenderer) {
            switch (cvarRenderer.GetInt()) {
                default:
                    projection = glProjection;
                    break;
                case 0:
                case 1:
                    projection = swProjection;
                    break;
            }
        } else {
            projection = glProjection;
        }
        isPrepared = (projection != null);
    }

    override void WorldLoaded(WorldEvent e) {
        keysInLevel.Clear();
        secretActors.Clear();
        exitPositionsX.Clear();
        exitPositionsY.Clear();
        exitPositionsZ.Clear();
        exitSpecials.Clear();
        secretSectors.Clear();

        if (!e.IsSaveGame) {
            playEntryPosValid = false;
        }

        spr_ykey = Actor.GetSpriteIndex("YKEY");
        spr_bkey = Actor.GetSpriteIndex("BKEY");
        spr_rkey = Actor.GetSpriteIndex("RKEY");
        spr_gkey = Actor.GetSpriteIndex("GKEY");
        spr_skey = Actor.GetSpriteIndex("SKEY");
        spr_gold = Actor.GetSpriteIndex("GOLD");
        spr_silv = Actor.GetSpriteIndex("SILV");
        spr_tnt1 = Actor.GetSpriteIndex("TNT1");

        // Scan Exits
        for (int i = 0; i < level.lines.Size(); i++) {
            Line l = level.lines[i];
            if (l.special == 243 || l.special == 244 || l.special == 74 || l.special == 75) {
                Vector2 mid2d = (l.v1.p + l.v2.p) * 0.5;
                double midz = l.frontsector ? l.frontsector.floorplane.ZAtPoint(mid2d) : 0.0;
                exitPositionsX.Push(mid2d.x);
                exitPositionsY.Push(mid2d.y);
                exitPositionsZ.Push(midz);
                exitSpecials.Push(l.special);
            }
        }

        // Scan Secrets
        for (int i = 0; i < level.sectors.Size(); i++) {
            Sector sec = level.sectors[i];
            if (sec.isSecret() || sec.wasSecret()) {
                secretSectors.Push(i);
            }
        }

        // Scan keys and weapons present at level load
        ThinkerIterator it = ThinkerIterator.Create("Actor");
        Actor mo;
        while (mo = Actor(it.Next())) {
            if (mo && (IsKeyActor(mo) || mo is "Weapon")) {
                keysInLevel.Push(mo);
            }
            if (mo && mo is "SecretTrigger") {
                secretActors.Push(mo);
            }
        }
    }

    override void WorldThingSpawned(WorldEvent e) {
        if (e.Thing && (IsKeyActor(e.Thing) || e.Thing is "Weapon")) {
            if (keysInLevel.Find(e.Thing) == keysInLevel.Size()) {
                keysInLevel.Push(e.Thing);
            }
        }
        if (e.Thing && e.Thing is "SecretTrigger") {
            if (secretActors.Find(e.Thing) == secretActors.Size()) {
                secretActors.Push(e.Thing);
            }
        }
    }

    override void WorldTick() {
        if (!playEntryPosValid && players[consoleplayer].mo) {
            playEntryPos = players[consoleplayer].mo.pos;
            playEntryPosValid = true;
        }

        PlayerInfo player = players[consoleplayer];

        for (int i = keysInLevel.Size() - 1; i >= 0; i--) {
            Actor k = keysInLevel[i];
            if (!k || k.bDestroyed || (k is "Inventory" && Inventory(k).owner != null) || (player && player.mo && k is "Inventory" && player.mo.FindInventory((class<Inventory>)(k.GetClass())))) {
                keysInLevel.Delete(i);
            }
        }
        for (int i = secretActors.Size() - 1; i >= 0; i--) {
            Actor s = secretActors[i];
            if (!s || s.bDestroyed) {
                secretActors.Delete(i);
            }
        }
    }

    private bool IsKeyActor(Actor act) const {
        if (!act || act.bDestroyed) return false;

        if (act is "Key" || (act is "Inventory" && Inventory(act).bIsKeyItem)) {
            return true;
        }

        string cname = act.GetClassName();
        cname.MakeLower();

        if (cname.IndexOf("key") != -1 ||
            cname.IndexOf("card") != -1 ||
            cname.IndexOf("skull") != -1) {
            return true;
        }

        SpriteID spr = act.sprite;
        if (spr == spr_ykey ||
            spr == spr_bkey ||
            spr == spr_rkey ||
            spr == spr_gkey ||
            spr == spr_skey ||
            spr == spr_gold ||
            spr == spr_silv) {
      
            return true;
        }

        return false;
    }

    private ui int GetKeyColorRange(Actor k) const {
        if (k is "Weapon") {
            return Font.CR_GOLD;
        }
        string cname = k.GetClassName();
        cname.MakeLower();

        if (cname.IndexOf("red") != -1 || k.sprite == spr_rkey) return Font.CR_RED;
        if (cname.IndexOf("blue") != -1 || k.sprite == spr_bkey) return Font.CR_BLUE;
        if (cname.IndexOf("yellow") != -1 || k.sprite == spr_ykey || k.sprite == spr_gold) return Font.CR_YELLOW;
        if (cname.IndexOf("green") != -1 || k.sprite == spr_gkey) return Font.CR_GREEN;
        if (cname.IndexOf("silver") != -1 || k.sprite == spr_silv) return Font.CR_GREY;

        return Font.CR_WHITE;
    }

    private ui bool ProjectWorldToScreen(Vector3 worldPos, KHT_Viewport viewport, out double screenX, out double screenY) {
        projection.ProjectWorldPos(worldPos);
        if (!projection.IsInFront()) return false;
        Vector2 sceneNormal = projection.ProjectToNormal();
        if (!viewport.IsInside(sceneNormal)) return false;
        Vector2 screenPos = viewport.SceneToWindow(sceneNormal);
        screenX = screenPos.x;
        screenY = screenPos.y;
        return true;
    }

    private ui void DrawHUDMarkerText(string tagStr, int tagColor, Vector2 screenPos, double yOffset, double distanceMeters, bool showDist, double uiAlpha, double uiScale) {
        // Scale text based on resolution (assume 1080p is scale 1.0) multiplied by user setting
        double resScale = max(1.0, Screen.GetHeight() / 1080.0);
        double finalScale = resScale * uiScale;
        
        double textHeight = smallfont.GetHeight() * finalScale;
        double textY = screenPos.y - textHeight / 2.0 + yOffset;
        
        // Thicker shadow outline for higher resolutions to maintain readability
        double outline = max(1.0, ceil(finalScale));

        if (tagStr.Length() > 0) {
            double textWidth = smallfont.StringWidth(tagStr) * finalScale;
            double textX = screenPos.x - textWidth / 2.0;

            screen.DrawText(smallfont, Font.CR_BLACK, textX + outline, textY + outline, tagStr, DTA_ScaleX, finalScale, DTA_ScaleY, finalScale, DTA_Alpha, uiAlpha);
            screen.DrawText(smallfont, Font.CR_BLACK, textX - outline, textY - outline, tagStr, DTA_ScaleX, finalScale, DTA_ScaleY, finalScale, DTA_Alpha, uiAlpha);
            screen.DrawText(smallfont, Font.CR_BLACK, textX + outline, textY - outline, tagStr, DTA_ScaleX, finalScale, DTA_ScaleY, finalScale, DTA_Alpha, uiAlpha);
            screen.DrawText(smallfont, Font.CR_BLACK, textX - outline, textY + outline, tagStr, DTA_ScaleX, finalScale, DTA_ScaleY, finalScale, DTA_Alpha, uiAlpha);
            screen.DrawText(smallfont, tagColor, textX, textY, tagStr, DTA_ScaleX, finalScale, DTA_ScaleY, finalScale, DTA_Alpha, uiAlpha);

            textY += textHeight + (2.0 * finalScale);
        }

        if (showDist) {
            string distStr = String.Format("%.0fm", distanceMeters);
            double dWidth = smallfont.StringWidth(distStr) * finalScale;
            double dX = screenPos.x - dWidth / 2.0;

            screen.DrawText(smallfont, Font.CR_BLACK, dX + outline, textY + outline, distStr, DTA_ScaleX, finalScale, DTA_ScaleY, finalScale, DTA_Alpha, uiAlpha);
            screen.DrawText(smallfont, Font.CR_BLACK, dX - outline, textY - outline, distStr, DTA_ScaleX, finalScale, DTA_ScaleY, finalScale, DTA_Alpha, uiAlpha);
            screen.DrawText(smallfont, Font.CR_BLACK, dX + outline, textY - outline, distStr, DTA_ScaleX, finalScale, DTA_ScaleY, finalScale, DTA_Alpha, uiAlpha);
            screen.DrawText(smallfont, Font.CR_BLACK, dX - outline, textY + outline, distStr, DTA_ScaleX, finalScale, DTA_ScaleY, finalScale, DTA_Alpha, uiAlpha);
            
            int distColor = (tagStr.Length() == 0) ? tagColor : Font.CR_WHITE;
            screen.DrawText(smallfont, distColor, dX, textY, distStr, DTA_ScaleX, finalScale, DTA_ScaleY, finalScale, DTA_Alpha, uiAlpha);
        }
    }

    override void RenderOverlay(RenderEvent e) {
        PlayerInfo player = players[consoleplayer];

        if (!player || !player.mo || player.mo.health <= 0 || gamestate == GS_TITLELEVEL || automapactive) {
            return;
        }

        InitCVars();
        if (cv_enabled && !cv_enabled.GetBool()) {
            return;
        }

        if (!isInitialized) {
            InitializeProjection();
        }

        PrepareProjection();
        if (!isPrepared) {
            return;
        }

        projection.CacheResolution();
        projection.CacheFov(player.fov);
        projection.OrientForRenderOverlay(e);
        projection.BeginProjection();

        KHT_Viewport viewport;
        viewport.FromHud();

        double uiScale = cv_scale ? cv_scale.GetFloat() : 1.0;
        double uiAlpha = cv_alpha ? cv_alpha.GetFloat() : 0.8;
        bool showDist = cv_show_distance ? cv_show_distance.GetBool() : true;
        double maxDist = cv_max_distance ? cv_max_distance.GetFloat() : 0.0;
        bool trackWeapons = cv_track_weapons ? cv_track_weapons.GetBool() : false;
        bool trackExits = cv_track_exits ? cv_track_exits.GetBool() : true;
        bool trackEntry = cv_track_entry ? cv_track_entry.GetBool() : true;
        bool trackSecrets = cv_track_secrets ? cv_track_secrets.GetBool() : true;

        // Track Keys & Weapons
        for (int i = keysInLevel.Size() - 1; i >= 0; i--) {
            Actor k = keysInLevel[i];
            if (!k || k.bDestroyed || (k is "Inventory" && Inventory(k).owner != null)) continue;
            if (k is "Weapon" && !trackWeapons) continue;

            double distanceUnits = (k.pos - player.mo.pos).Length();
            double distanceMeters = distanceUnits / 32.0;

            if (maxDist > 0.0 && distanceMeters > maxDist) continue;

            double floatOffset = 4.0 * sin(level.time * 2.0);
            Vector3 keyPos = k.pos + (0, 0, k.height + 8.0 + floatOffset);
            
            double screenX, screenY;
            if (!ProjectWorldToScreen(keyPos, viewport, screenX, screenY)) continue;
            Vector2 screenPos = (screenX, screenY);

            TextureID keyIcon = k.CurState.GetSpriteTexture(0);
            if (!keyIcon.IsValid() || k.CurState.Sprite == spr_tnt1) continue;

            Vector2 texSize = TexMan.GetScaledSize(keyIcon);
            if (texSize.y <= 0.0) continue;

            double targetHeight = 32.0 * (Screen.GetHeight() / 1080.0) * uiScale;
            double scaleFactor = targetHeight / texSize.y;

            screen.DrawTexture(keyIcon, true, screenPos.x, screenPos.y,
                DTA_DestWidthF, texSize.x * scaleFactor,
                DTA_DestHeightF, texSize.y * scaleFactor,
                DTA_CenterOffset, true,
                DTA_Alpha, uiAlpha);

            // Dynamically scale text offset
            double resScale = max(1.0, Screen.GetHeight() / 1080.0);
            double finalScale = resScale * uiScale;
            double textHeight = smallfont.GetHeight() * finalScale;
            double yOffset = - (targetHeight / 2.0) - textHeight / 2.0 - (4.0 * finalScale);
            
            DrawHUDMarkerText("", GetKeyColorRange(k), screenPos, yOffset, distanceMeters, showDist, uiAlpha, uiScale);
        }

        // Track Level Exits
        if (trackExits) {
            for (int i = 0; i < exitPositionsX.Size(); i++) {
                Vector3 exitPos = (exitPositionsX[i], exitPositionsY[i], exitPositionsZ[i]);

                double distanceUnits = (exitPos - player.mo.pos).Length();
                double distanceMeters = distanceUnits / 32.0;

                if (maxDist > 0.0 && distanceMeters > maxDist) continue;

                double floatOffset = 2.0 * sin(level.time * 2.0 + i);
                Vector3 projPos = exitPos + (0, 0, 32.0 + floatOffset);

                double screenX, screenY;
                if (!ProjectWorldToScreen(projPos, viewport, screenX, screenY)) continue;
                Vector2 screenPos = (screenX, screenY);

                int special = exitSpecials[i];
                string tagStr = (special == 244) ? "SECRET EXIT" : "EXIT";
                int tagColor = (special == 244) ? Font.CR_GOLD : Font.CR_RED;
                
                DrawHUDMarkerText(tagStr, tagColor, screenPos, 0, distanceMeters, showDist, uiAlpha, uiScale);
            }
        }

        // Track Level Entry
        if (trackEntry && playEntryPosValid) {
            double distanceUnits = (playEntryPos - player.mo.pos).Length();
            double distanceMeters = distanceUnits / 32.0;

            if (maxDist <= 0.0 || distanceMeters <= maxDist) {
                double floatOffset = 2.0 * sin(level.time * 2.0);
                Vector3 projPos = playEntryPos + (0, 0, 32.0 + floatOffset);

                double screenX, screenY;
                if (ProjectWorldToScreen(projPos, viewport, screenX, screenY)) {
                    Vector2 screenPos = (screenX, screenY);
                    DrawHUDMarkerText("START", Font.CR_GREEN, screenPos, 0, distanceMeters, showDist, uiAlpha, uiScale);
                }
            }
        }

        // Track Secrets
        if (trackSecrets) {
            for (int i = 0; i < secretSectors.Size(); i++) {
                Sector sec = level.sectors[secretSectors[i]];

                if (!sec || !sec.isSecret()) continue;

                Vector2 center2d = sec.centerspot;
                double floorZ = sec.floorplane.ZAtPoint(center2d);
                double ceilZ = sec.ceilingplane.ZAtPoint(center2d);
                double heightClamp = min((ceilZ - floorZ) * 0.5, 48.0);
                double midZ = floorZ + heightClamp;

                Vector3 secretPos = (center2d.x, center2d.y, midZ);

                double distanceUnits = (secretPos - player.mo.pos).Length();
                double distanceMeters = distanceUnits / 32.0;

                if (maxDist > 0.0 && distanceMeters > maxDist) continue;

                double floatOffset = 2.0 * sin(level.time * 2.0 + i);
                Vector3 projPos = secretPos + (0, 0, floatOffset);

                double screenX, screenY;
                if (!ProjectWorldToScreen(projPos, viewport, screenX, screenY)) continue;
                Vector2 screenPos = (screenX, screenY);

                DrawHUDMarkerText("SECRET", Font.CR_PURPLE, screenPos, 0, distanceMeters, showDist, uiAlpha, uiScale);
            }

            for (int i = 0; i < secretActors.Size(); i++) {
                Actor sec = secretActors[i];

                if (!sec || sec.bDestroyed) continue;

                double distanceUnits = (sec.pos - player.mo.pos).Length();
                double distanceMeters = distanceUnits / 32.0;

                if (maxDist > 0.0 && distanceMeters > maxDist) continue;

                double floatOffset = 2.0 * sin(level.time * 2.0 + i + 100);
                Vector3 projPos = sec.pos + (0, 0, (sec.height * 0.5) + floatOffset);

                double screenX, screenY;
                if (!ProjectWorldToScreen(projPos, viewport, screenX, screenY)) continue;
                Vector2 screenPos = (screenX, screenY);

                DrawHUDMarkerText("SECRET", Font.CR_PURPLE, screenPos, 0, distanceMeters, showDist, uiAlpha, uiScale);
            }
        }
    }
}