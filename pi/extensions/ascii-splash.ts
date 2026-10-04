import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { mixColors, parseColor, truncateToWidth } from "@earendil-works/pi-tui";

// Voronoi sites give the logo broad, repeatable color regions. Their positions
// move during rendering; Y is scaled for terminal cell shape.
const sites = [
  [8, 5], [25, 2], [43, 5], [60, 2],
  [5, 16], [26, 14], [42, 18], [60, 14],
] as const;

// 72 columns × 21 rows: adjusted for the aspect ratio of terminal characters.
const logo = `                ++*+***+*++++*+*                            *+*++++*+***
           *+++*##@##%%%%##%%##**++*+                     +#*#%#%#%#%%#*
        *+#*###%#%##%%###%%%%%@%%%%#***+                +#*#@#@#%%%%#%#*
      +*#%##%#%%%##*+*+*++***##%%@%#%@%o+*            **#%%@%##@@##%@#@+
    +**o##%@#%#*+*+          ***#%%#%%*#+           ***@%%#%%%#####%%@%+
   +*%%##%%###+                 +****#+           +##@###@@%##*#%@#####+
 +#*#@#@%##*+                      *+           **##%%@%#%o#+ #%%o%####*
 *%@%%%#%#*                                   +*###%%##@##*   *#%%%%%#%*
+##@#@#@%#*                                 +#*%#%%%###**     +##@%%#%#*
*o%%#%%%@*                           *+*+++#*#%##%%#*#*       *%%#%@#%#*
+#####%##+                         *#*@%%%#@#%%#%%##+         +#%@#####*
*@#%@%##%+                       +**##%*#+++####@%#           +#%%##%%%*
+#####%#%#                      +#%#%%#+     ###%%*+          +%%%##@#@+
 *####%#%#+                     +*#%o#*      *%#%#**          +@###%%%#*
 +###%%%#%*+                     ####%*#++*+*#%@#*+           +##%#%###+
  +##@%%@%#**+                   #%%#@###%####%#*+            *%%####%#+
    +###%%#####+*+           *++*##@#@@##*#*+++*              *%%@#%%%#+
     ++*o##@#%%@#**+*+++***+*##@%#%%#%#*#+                    +o%#%##%#+
        **#*%%######@##%#%%#o#%#%%%#*#++                      +%#%%%@##+
           *++##%%@%#%@%%#####%#*+++*                         *#####%##+
               +++*++++**++**+++                              *+++++*+**`.split("\n");

export default function (pi: ExtensionAPI) {
  let stopAnimation: (() => void) | undefined;

  pi.on("session_start", (_event, ctx) => {
    if (ctx.mode !== "tui") return;
    stopAnimation?.();

    ctx.ui.setHeader((tui, theme) => {
      const started = Date.now();
      const timer = setInterval(() => tui.requestRender(), 120);
      const stop = () => {
        clearInterval(timer);
        if (stopAnimation === stop) stopAnimation = undefined;
      };
      stopAnimation = stop;

      return {
      render(width: number) {
        if (width < 72) return [theme.fg("accent", "C1")];

        const light = theme.appearance === "light";
        const regions = (light
          ? ["#006f78", "#164da0", "#006c57", "#564397", "#077b73", "#075f99", "#74458a", "#00675a"]
          : ["#3bc6c5", "#688fea", "#29c998", "#a783ed", "#26b4a4", "#60b2ef", "#c08de5", "#4cd6b0"]
        ).map(parseColor);
        const highlight = parseColor(light ? "#004939" : "#baf9df");
        const gold = parseColor(light ? "#975000" : "#ffd166");
        const seconds = (Date.now() - started) / 1000;
        // Actually move the sites, so the colored regions flow across the logo.
        const movingSites = sites.map(([sx, sy], i) => [
          sx + 5 * Math.sin(seconds * 0.95 + i * 2.1),
          sy + 1.9 * Math.cos(seconds * 0.75 + i * 1.7),
        ] as const);

        return logo.map((line, y) => {
          let colored = "";
          for (let x = 0; x < line.length; x++) {
            const char = line[x];
            if (char === " ") {
              colored += " ";
              continue;
            }

            let nearest = Infinity;
            let second = Infinity;
            let region = 0;
            for (let i = 0; i < movingSites.length; i++) {
              const [sx, sy] = movingSites[i];
              const distance = (x - sx) ** 2 + (2 * (y - sy)) ** 2;
              if (distance < nearest) {
                second = nearest;
                nearest = distance;
                region = i;
              } else if (distance < second) {
                second = distance;
              }
            }

            // Slowly drift color through each cell; send a gentle wave across
            // boundaries and edges without changing the logo's silhouette.
            const drift = 0.13 + 0.12 * Math.sin(seconds * 0.8 + region * 1.7);
            let color = mixColors(regions[region], regions[(region + 1) % regions.length], drift);
            const wave = 0.5 + 0.5 * Math.sin(x * 0.23 - y * 0.33 - seconds * 2);
            if (second - nearest < 24) color = mixColors(color, highlight, 0.16 + 0.3 * wave);
            if (char === "+") color = mixColors(color, highlight, 0.28 + 0.24 * wave);
            else if (char === "*" || char === "@") color = mixColors(color, highlight, 0.13 + 0.16 * wave);
            else if (char === "o") color = mixColors(gold, highlight, 0.12 + 0.3 * wave);
            colored += theme.style(char, { fg: color });
          }
          return truncateToWidth(colored, width);
        });
      },
      invalidate() {},
      dispose: stop,
    };
    });
  });

  pi.on("session_shutdown", () => stopAnimation?.());
}
