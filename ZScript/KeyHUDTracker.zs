// Standalone Key HUD Tracker Mod for GZDoom / UZDoom
// Ported mathematical projection formulas from libeye by KeksDose

class KHT_ProjScreen {
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

    virtual void Reorient(vector3 world_view_pos, vector3 world_ang) {
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

        // Obtain status bar offset to position projection properly
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
    private transient bool isInitialized;
    private transient bool isPrepared;
    private transient CVar cvarRenderer;
    private KHT_ProjScreen projection;
    private KHT_GlScreen glProjection;
    private KHT_SwScreen swProjection;

    // Cached CVars
    private transient CVar cv_enabled;
    private transient CVar cv_scale;
    private transient CVar cv_alpha;
    private transient CVar cv_show_distance;
    private transient CVar cv_max_distance;

    private Array<Actor> keysInLevel;

    private void InitCVars() {
        PlayerInfo player = players[consoleplayer];
        if (!player || cv_enabled) return;

        cv_enabled = CVar.GetCVar("key_tracker_enabled", player);
        cv_scale = CVar.GetCVar("key_tracker_scale", player);
        cv_alpha = CVar.GetCVar("key_tracker_alpha", player);
        cv_show_distance = CVar.GetCVar("key_tracker_show_distance", player);
        cv_max_distance = CVar.GetCVar("key_tracker_max_distance", player);
        cvarRenderer = CVar.GetCVar("vid_rendermode", player);
    }

    private void InitializeProjection() {
        glProjection = new("KHT_GlScreen");
        swProjection = new("KHT_SwScreen");
        isInitialized = true;
    }

    private void PrepareProjection() {
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
        isInitialized = false;
        isPrepared = false;

        // Scan keys present at level load
        ThinkerIterator it = ThinkerIterator.Create("Actor");
        Actor mo;
        while (mo = Actor(it.Next())) {
            if (mo && IsKeyActor(mo)) {
                keysInLevel.Push(mo);
            }
        }
    }

    override void WorldThingSpawned(WorldEvent e) {
        if (e.Thing && IsKeyActor(e.Thing)) {
            if (keysInLevel.Find(e.Thing) == keysInLevel.Size()) {
                keysInLevel.Push(e.Thing);
            }
        }
    }

    private bool IsKeyActor(Actor act) const {
        if (!act || act.bDestroyed) return false;

        if (act is "Key" || act.bIsKeyItem) {
            return true;
        }

        string cname = act.GetClassName();
        cname.MakeLower();
        if (cname.IndexOf("key") != -1 ||
            cname.IndexOf("card") != -1 ||
            cname.IndexOf("skull") != -1 ||
            cname.IndexOf("pass") != -1 ||
            cname.IndexOf("token") != -1 ||
            cname.IndexOf("badge") != -1 ||
            cname.IndexOf("intel") != -1 ||
            cname.IndexOf("code") != -1 ||
            cname.IndexOf("plans") != -1) {
            return true;
        }
        return false;
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

        for (int i = keysInLevel.Size() - 1; i >= 0; i--) {
            Actor k = keysInLevel[i];

            if (!k || k.bDestroyed || k.owner != null || (k is "Inventory" && Inventory(k).owner != null)) {
                keysInLevel.Delete(i);
                continue;
            }

            double distanceUnits = (k.pos - player.mo.pos).Length();
            double distanceMeters = distanceUnits / 32.0;

            if (maxDist > 0.0 && distanceMeters > maxDist) {
                continue;
            }

            // Micro-animation: float the HUD hologram icon smoothly using a sine wave
            double floatOffset = 4.0 * sin(level.time * 2.0);
            Vector3 keyPos = k.pos + (0, 0, k.height + 8.0 + floatOffset);

            projection.ProjectWorldPos(keyPos);
            if (!projection.IsInFront()) {
                continue;
            }

            Vector2 sceneNormal = projection.ProjectToNormal();
            if (!viewport.IsInside(sceneNormal)) {
                continue;
            }

            Vector2 screenPos = viewport.SceneToWindow(sceneNormal);

            TextureID keyIcon = k.CurState.GetSpriteTexture(0);
            if (!keyIcon.IsValid()) {
                continue;
            }

            Vector2 texSize = TexMan.GetScaledSize(keyIcon);
            if (texSize.y <= 0.0) continue;

            double targetHeight = 32.0 * (Screen.GetHeight() / 1080.0) * uiScale;
            double scaleFactor = targetHeight / texSize.y;

            // Draw the key sprite texture centered
            screen.DrawTexture(keyIcon, true, screenPos.x, screenPos.y,
                DTA_DestWidthF, texSize.x * scaleFactor,
                DTA_DestHeightF, texSize.y * scaleFactor,
                DTA_CenterOffset, true,
                DTA_Alpha, uiAlpha);

            // Draw distance text in meters
            if (showDist) {
                string distStr = String.Format("%.0fm", distanceMeters);
                double textWidth = smallfont.StringWidth(distStr);
                double textX = screenPos.x - textWidth / 2.0;
                double textY = screenPos.y + (targetHeight / 2.0) + 4.0;

                // Draw drop shadow using 4-directional outline offset for maximum clarity
                screen.DrawText(smallfont, Font.CR_BLACK, textX + 1, textY + 1, distStr, DTA_Alpha, uiAlpha);
                screen.DrawText(smallfont, Font.CR_BLACK, textX - 1, textY - 1, distStr, DTA_Alpha, uiAlpha);
                screen.DrawText(smallfont, Font.CR_BLACK, textX + 1, textY - 1, distStr, DTA_Alpha, uiAlpha);
                screen.DrawText(smallfont, Font.CR_BLACK, textX - 1, textY + 1, distStr, DTA_Alpha, uiAlpha);

                // Draw main text
                screen.DrawText(smallfont, Font.CR_WHITE, textX, textY, distStr, DTA_Alpha, uiAlpha);
            }
        }
    }
}
