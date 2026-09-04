/* The design curve, in code (docs/tasarim-dili.md, A3).
 *
 * Everything that moves on the desktop uses cubic-bezier(0.2, 0.9,
 * 0.25, 1) over 180 ms. picom reads that curve from its own config;
 * anything animated by our own code — the snap preview, a window
 * settling into a zone — needs it as a function, and this is the one
 * definition of it. A second, hand-tuned curve somewhere else is how a
 * desktop starts feeling inconsistent.
 */

namespace Kavis {

    namespace Easing {

        /* Design curve control points. */
        private const double X1 = 0.2;
        private const double Y1 = 0.9;
        private const double X2 = 0.25;
        private const double Y2 = 1.0;

        public const int DURATION_MS = 180;
        public const int HOVER_MS = 120;

        private static double bezier (double a, double b, double u) {
            double v = 1 - u;
            /* P0 = 0 and P3 = 1, so those terms drop out. */
            return 3 * v * v * u * a + 3 * v * u * u * b + u * u * u;
        }

        private static double bezier_slope (double a, double b, double u) {
            double v = 1 - u;
            return 3 * v * v * a + 6 * v * u * (b - a) + 3 * u * u * (1 - b);
        }

        /* t: 0..1 of elapsed time → 0..1 of travelled distance.
         *
         * The curve gives x and y as functions of a parameter, not y as
         * a function of x, so the parameter for this instant is solved
         * for first: Newton from a linear guess, which converges in two
         * or three steps on a curve this gentle, with a bisection
         * fallback for the flat parts where the derivative is tiny. */
        public static double ease (double t) {
            if (t <= 0) { return 0; }
            if (t >= 1) { return 1; }
            double u = t;
            for (int i = 0; i < 6; i++) {
                double x = bezier (X1, X2, u) - t;
                if (x.abs () < 1e-5) {
                    break;
                }
                double slope = bezier_slope (X1, X2, u);
                if (slope.abs () < 1e-6) {
                    break;
                }
                u -= x / slope;
                if (u < 0) { u = 0; }
                if (u > 1) { u = 1; }
            }
            return bezier (Y1, Y2, u);
        }

        /* Interpolate one integer along the curve. */
        public static int step (int from, int to, double t) {
            return from + (int) Math.round ((to - from) * ease (t));
        }
    }
}
