# Knowledge-Completeness Review Report (2026-11-07)

Review method: 8 parallel review groups going lesson by lesson + cross-checking. Of the 175 lessons, about 150 were read in full; 04-02~04-10, 05-02~05-06, 10-05~06, 11-04~06, and 21-04~06 were judged at heading level plus spot checks of representative lessons; for 00/01/02/19/22/23/24/25, about 5 lessons per field were spot-checked. Every error marked "high" was confirmed by a second independent re-check.

## 1. Overall verdict

| Dimension | Assessment |
|---|---|
| Engineering and integrity | **Excellent**. The statistics 175/25/19/369 all match reality; the disclaimers are consistent with the actual level of completion; CI includes an idempotent rebuild check; content is generated from a single source, with no drift |
| Content correctness | **Generally reliable, but 9 verified errors exist** (see §2), concentrated in transfer-exercise solutions and worked-example numbers |
| Knowledge completeness | **The main weakness**. The field framework (25 fields + mapping to the 51 arXiv codes) is sound, but within each field roughly half of the "textbook backbone" is missing (see §3); lesson depth stays at outline level (see §4) |

## 2. Verified content errors (fix immediately recommended; every fix requires editing the tools/*.py content sources and rebuilding)

| # | File | Problem | Correction |
|---|---|---|---|
| 1 | [07-量子力学/09.html](07-量子力学/09.html) transfer-exercise solution | 100 mb is written as 10⁻²⁶ cm², and the event rate is given as 100 s⁻¹ | 100 mb = 10⁻²⁵ cm², event rate = 10²⁸×10⁻²⁵ = **10³ s⁻¹** (off by a factor of 10) |
| 2 | [07-量子力学/11.html](07-量子力学/11.html) worked example | Says "the harmonic-oscillator propagator = e^{iS_cl/ℏ} times a Hermite-polynomial factor" | The correct result is the Mehler kernel **√(mω/2πiℏ·sinωT)·e^{iS_cl/ℏ}**; the extra factor is the normalization prefactor, and the Hermite polynomials belong to the eigenfunctions ψₙ |
| 3 | [09-凝聚态与材料物理/04.html](09-凝聚态与材料物理/04.html) | Gives only the first London equation m(dJ/dt)=n_se²E, yet claims that "combined with Maxwell's equations it yields exponential decay" | The first equation is equivalent only to a perfect conductor (frozen-in flux); the Meissner effect requires the **second London equation ∇×J_s=−n_se²B/m** to obtain ∇²B=B/λ². The current derivation contradicts this lesson's own transfer exercise, "a perfect conductor does not expel magnetic flux" |
| 4 | [14-地球物理与空间物理/04.html](14-地球物理与空间物理/04.html) | ① "The absence of SKS proves the outer core is liquid" ② "PKIKP propagates a shear-wave component thanks to the inner core's shear modulus" | ① SKS is a routinely observed phase (S→K→S, with the K leg a P wave); the correct evidence is the **absence of any pure S phase crossing the outer core / the S-wave shadow zone**. ② Every leg of PKIKP is longitudinal; the evidence for a solid inner core is **PKJKP** (J leg is shear) |
| 5 | [18-实验物理与测量/04.html](18-实验物理与测量/04.html) | The equivalent noise bandwidth is written as B≈1/(2τ), giving 0.5 Hz for τ=1 s and a gain ≈140; and "SNR∝signal×√(τ/bandwidth)" is dimensionally muddled | For a single-pole RC output filter the **ENB = 1/(4τ)** = 0.25 Hz, gain √(10⁴/0.25)≈**200**; the formula should read SNR ∝ signal/√B |
| 6 | [19-流体与连续介质物理/03.html](19-流体与连续介质物理/03.html) worked example | "At Re=10⁶, η≈L/5600" | By the lesson's own formula η∝L·Re^(−3/4) = L/32000 ≈ **30 μm** (L=1 m), contradicting its own formula (off by about a factor of 5.6) |
| 7 | [07-量子力学/04.html](07-量子力学/04.html) | "ν=2.42×10¹⁴ Hz is exactly a visible-light frequency" | 1 eV ↔ 1240 nm is **near infrared**; visible light requires ≈1.65–3.26 eV (4–7.9×10¹⁴ Hz) |
| 8 | [13-天体物理与宇宙学/04.html](13-天体物理与宇宙学/04.html) outline | Claims "solving the equations jointly yields the L–M relation" can be derived as an exercise | L∝M^3.5 is an empirical/numerical law; an analytical derivation requires extra assumptions (power-law κ and ε + the Eddington standard model). It cannot be derived by following the listed steps, and the Eddington luminosity is also missing |
| 9 | [03-热力学与统计物理/08.html](03-热力学与统计物理/08.html) worked example | "At standard conditions, air has v̄≈470 m/s" | 470 m/s is the 300 K value; at standard conditions (273 K, consistent with the n=2.7×10²⁵ m⁻³ of the same example) it should be about **450 m/s** |

Secondary issues (fix in the same pass): 12-05 says ITER "covers the ignition margin" (ITER is a Q=10 gain design, not ignition); the external link in the 00-04 linear-algebra lesson points to "single-variable calculus" (assigned by field, mismatched with the topic); 06-04 uses g₀₀=−(1−r_s/r) without declaring the metric signature (−,+,+,+); 07-06 lists "angular momentum" as a prerequisite for the hydrogen atom while that lesson (07-07) comes later — the lesson order is inverted; 07-08 describes the singlet state as "spins antiparallel" (the singlet is a ↑↓−↓↑ superposition).

## 3. Backbone gaps within fields (the core knowledge-completeness problem)

The 25-field framework and its mapping to the 51 arXiv codes are sound, and the assignments are broadly reasonable, but **within each field only about 1–2 chapters of a standard textbook are covered**, so the "introductory-to-research-readiness" backbone is missing half its substance across the board. Ordered by severity of damage:

### The four foundational theories (crippling gaps)
- **07 Quantum Mechanics (11 lessons)**: missing **time-dependent perturbation theory and Fermi's golden rule** (the mechanism behind 07-04 "how atoms emit light" and 07-06 energy-level transitions is therefore left hanging) and **tunneling and finite potential wells** (the whole site has only the infinite well); P1: the variational method, WKB, angular-momentum coupling (Clebsch–Gordan), the density matrix, and the many-body foundations of identical particles (lesson 8 reaches only concept level, with no Slater determinants/exchange energy/Fermi gas)
- **04 Electromagnetism (10 lessons)**: missing **electromagnetism in media** (polarization P/D, magnetization M/H, the four boundary conditions — the method of images covers only the conductor special case) and **inductance, LR/LC transients, and AC impedance**; P1: multipole expansion, waves in media/conductors and skin depth, and the magnetic-force side (Lorentz force/Hall effect)
- **03 Thermodynamics and Statistical Physics (10 lessons)**: missing the **Maxwell–Boltzmann distribution**, the **microcanonical/canonical/grand-canonical ensemble framework**, a **definition of the chemical potential μ** (lessons 06/07 list μ as a prerequisite but it is never defined anywhere on the site — the prerequisite chain is broken), and **Fermi–Dirac statistics and the degenerate Fermi gas**; P1: systematic applications of the partition function, quantitative BEC, Langevin/Brownian motion
- **06 Relativity (6 lessons)**: missing the **explicit construction of the Lorentz transformation and spacetime diagrams** (nowhere on the site: x′=γ(x−vt), relativity of simultaneity, a derivation of length contraction) and the **complete Schwarzschild metric line element** (only the g₀₀ special case); the prerequisites of 06-05 (spacetime diagrams, the equivalence principle) have no lessons anywhere on the site

### The toolchain left hanging (a cross-field structural problem)
- **16 Mathematical Physics (6 lessons)**: missing **Fourier transform pairs/convolution/the δ function** (only trigonometric series exist), the **big three special functions** (Legendre/spherical harmonics, Bessel, Hermite — which 07-05/07-06 are already using), and **Green's functions** (the index has the tag but no lesson), plus the calculus of variations (07-11's prerequisite left hanging). One field's missing lessons leave several other fields hanging in turn

### Broken backbones in the specialty fields (each row is P0)
| Field | Missing backbone |
|---|---|
| 13 Astrophysics | All of stellar evolution after the main sequence + compact remnants (white dwarfs/Chandrasekhar limit/neutron stars); the distance ladder and magnitudes; the evidence chain for dark energy (05/06 invoke ΛCDM without evidence) |
| 14 Geophysics and space | **Plate tectonics (zero lessons)**, **geochronology (zero lessons)**, half of space physics (magnetosphere/solar wind/space weather are navigation tags only) |
| 15 Biophysics and medical | **Principles of MRI (zero lessons)**, **radiation dose units Gy/Sv/Bq (zero lessons)**, X-ray diffraction/structural biology, physics of DNA |
| 09 Condensed matter | Phonons and lattice heat capacity (Einstein/Debye); the free-electron gas and Fermi-energy estimates; p-n junctions and semiconductor devices; Bloch's theorem/reciprocal lattice |
| 08 AMO | Electric-dipole selection rules and Einstein A/B coefficients; quantitative fine/hyperfine structure; the Zeeman effect (tagged on the field page but carried by no lesson) |
| 10 Nuclear | The β-decay continuous spectrum and the neutrino; fission chain reactions/criticality; the fusion Lawson criterion (10-03 is one step away) |
| 11 Particle | A full table of the Standard Model particle spectrum; an introduction to Feynman-diagram rules; weak interactions/CKM/CP and the Higgs mechanism at a qualitative level (the current 04–06 EFT/lattice/AdS material is P2 methodology occupying the slot of P0 phenomenology) |
| 12 Plasma | Magnetic pressure and the β parameter; drift motion (E×B/gradient/curvature — used in lesson 05 yet never taught); collisional transport; the N_D criterion |
| 17 Computational | FFT; numerical eigenvalue problems; RK4/stiff ODEs; reproducible workflows (currently one passing sentence in research) |
| 18 Experimental | Poisson counting statistics (√N); chi-square tests and p values (χ² is computed but never compared with the degrees of freedom); the sampling theorem and aliasing |
| 20 Nonlinear | The Lorenz equations and strange attractors (chaos rests entirely on 1D maps); Poincaré sections; bifurcation typology (saddle-node/transcritical/Hopf all missing) |
| 21 Quantum information | Quantitative CHSH (02 has a single sentence, no 2√2 bound and no correlation functions); **at least one quantum algorithm** (Deutsch/Grover/Shor all absent); the Bloch sphere; teleportation/no-cloning |
| 05 Optics | The grating equation; thin-film interference; Gaussian beams and cavity stability conditions ("the laser lesson has no cavity"); the quantitative single-slit intensity distribution |
| 19 Fluids | Derivation of Navier–Stokes; vorticity and Kelvin's circulation theorem; surface tension (a textbook backbone) |
| 01 Mechanics | Normal modes of small oscillations (at the analytical-mechanics level); the inertia tensor; continuum fundamentals (stress/strain) |
| 02 Waves | Derivation of the wave equation from the forces on a string; the full Doppler formula; group velocity and wave packets |
| 00 Preparation | Methods for ordinary differential equations (a prerequisite across the board, no lesson) |
| 22 Chemical physics | HF/DFT concepts; intermolecular forces (van der Waals/hydrogen bonds); applications of the partition function to chemical equilibrium |
| 23 Accelerators | The transverse β function and Courant–Snyder parameters; synchrotron oscillations; collective effects (wakefields/space charge) |
| 24 Applied and energy | Quantitative convective/radiative heat transfer (conduction only); semiconductor devices; battery thermodynamics |
| 25 Foundations, history, education | The history of key experiments (Michelson–Morley/Millikan/Rutherford/Franck–Hertz); the SI 2019 redefinition of the units |

## 4. Lesson depth and the self-test system (a structural "last mile" problem)

1. **Derivations reduced to skeleton outlines**: each lesson body runs about 500–800 characters — 1 formula + 2–4 lines of outline, then "please fill in the intermediate algebra on paper." In several places the core difficulty is exactly what gets left blank (09-04 the second London equation, 09-05 the topological argument from Landau levels to conductance, 08-05 damping–diffusion equilibrium, 07-05 series truncation) — what students get stuck on is the necessary steps, not the algebra. Recommendation: write the key intermediate steps into the lesson text as collapsible `<details>` blocks (preserving the closed-book exercise scaffolding), or at least indicate at which step the gap sits.
2. **Self-tests collapsed to a single step**: the vast majority of numerical questions are one-step substitution or proportion problems (the ×4, ×9, 2³=8 type), and a few degenerate into pure arithmetic (310, 3−2=1); unit conversion is never tested (high-frequency errors like ℃→K never appear), nor order-of-magnitude estimation. Recommend 3–5 tiered numerical questions per lesson (including 1 requiring a conversion or multiple steps + 1 limiting/boundary case).
3. **Reviews reuse the same question**: redoing the identical question on days 1/3/7 means memorized answers contaminate review validity. Recommend parameter randomization (different numbers each time, answers judged by formula).
4. **Grading tolerance too tight**: course.js judges `|v−e| ≤ max(1e-6, 0.001|e|)`. For an answer with 3 significant figures (e.g. e⁻²≈0.135), a learner entering 0.1353 is marked wrong. Recommend relaxing according to the answer's number of significant digits (e.g. 1%–2%), or stating the required precision uniformly in the question.
5. **Transfer exercises are a highlight** (counterexample-style questioning, applicability-boundary sections); worth keeping and extending into tiered lines of questioning.
6. **The research-training pages are high quality** (replication goals, misinterpretation warnings, unified rubrics); they are the part of the site that best embodies "research readiness."

## 5. Engineering and consistency (cross-cutting verification results)

**Verified correct**: 175 lessons / 25 research trainings / 19 interactive figures / 369 direction entries (taxonomy 373 li = 369 entries + 4 methodology items) are all accurate; checklist 204 li = 175 lessons + 25 research + 4 criteria items, no missing lessons; 400 data-key values, no duplicates; CI (`git diff --exit-code` after build) suffices to prevent hand-edited artifacts; `__pycache__` is not tracked by git; content is generated from a single source (build_course.py is the sole entry point), no dual-source drift.

**To improve**:
1. **Progress does not sync**: the same lesson uses two independent localStorage keys on the lesson page (`07-deep-5`) and the checklist page (`cl-07-4`); checking one does not update the other; and because the keys are positional indices, inserting a lesson silently misaligns them. Recommend unifying the key names (stable slugs).
2. **Mapping tweaks** (classification-reference.json, 3 items): `physics.gen-ph→[0]` should add 25 (Learning Preparation ≠ general-physics navigation); `physics.flu-dyn→[19]` should add 14 (the arXiv description includes geophysical flows); `physics.class-ph→[1,2,4]` clearly lacks **3 (thermodynamics)** — classical physics = mechanics + heat + electromagnetism.
3. **Changes must land in the content sources**: the HTML is a generated artifact; editing it directly gets overwritten by `python tools/build_course.py` and flagged by CI. Error fixes should edit `tools/build_course.py` (DATA basic lessons), `tools/core_expansion.py` (CORE), `tools/advanced_content.py` (LESSONS), `tools/expanded_fields.py` (FIELDS/EXTRA/PROJECTS) and then rebuild.
4. Minor items: no dark-mode adaptation (the CSS could declare light-only); a few duplicate external links between RESOURCES and learning-path (harmless).

## 6. Priority roadmap

**P0 (immediate, hours of work)**: fix the 9+6 errors of §2 (edit the .py sources → `python tools/build_course.py` → commit; CI re-checks automatically).

**P1 (first batch of high-leverage new lessons, each plugging several P0 gaps, about 18)**:
1. 07 "Time-Dependent Perturbation Theory and Fermi's Golden Rule: How an Atom Emits Light"
2. 04 "Polarization and Magnetization: Maxwell's Equations in Media"
3. 03 "The Maxwell–Boltzmann Distribution and the Three Ensembles (including the chemical potential)"
4. 16 "Legendre, Bessel, and Hermite: Special Functions and Orthogonal Expansions"
5. 06 "The Lorentz Transformation and Spacetime Diagrams: Relativity of Simultaneity and Length Contraction"
6. 13 "The Life of a Star: After the Main Sequence and the Compact Remnants"
7. 14 "Plate Tectonics and Geochronology"
8. 15 "MRI Physics: Spins, Relaxation, and Gradient Encoding"
9. 09 "Phonons and the Heat Capacity of Solids: From Einstein to the Debye T³"
10. 10 "The β-Decay Continuous Spectrum and the Neutrino: A Complete Map of the Three Decays"
11. 11 "The Standard-Model Particle Spectrum and an Introduction to Feynman Diagrams"
12. 12 "Magnetic Pressure and the Plasma β"
13. 17 "FFT and Numerical Spectral Analysis"
14. 18 "Poisson Counting and Chi-Square Goodness of Fit"
15. 20 "The Lorenz Equations and the Strange Attractor (with Poincaré Sections)"
16. 21 "Quantitative CHSH and Grover's Algorithm"
17. 05 "Optical Cavities and Gaussian Beams: The Optical Half of a Laser"
18. 08 "Fine Structure, the Zeeman Effect, and the 21 cm Line"

**P2 (system upgrades)**: tiered self-tests and parameter randomization; filling derivation gaps with details blocks; syncing the progress keys between the lesson and checklist pages; the 3 mapping tweaks; relaxing the grading tolerance; a conversion pipeline from "taxonomy pending entries → new lessons" (the navigation tree already marks unwritten topics honestly and can serve directly as the backlog).

## 7. Review coverage and limitations

- Read lesson by lesson in full: 00, 01, 02, 03, 06, 07, 08, 09, 12, 13, 14, 15, 16, 17, 18, 19, 20, plus 10-01~04, 11-01~03, 21-01~03, 22-03, 23-02, 24-03/06, 25-05, and others.
- Heading-level + representative-lesson spot checks: 04-02~10, 05-02~06, 10-05~06, 11-04~06, 21-04~06, and the remaining lessons of 22/23/24/25. No content errors were found in these fields, but lesson-level detail was not fully covered.
- This report is a documentation review and does not replace item-by-item review by domain experts; every "correct value" cited was independently recomputed and confirmed by the reviewers.

## 8. Fix log (round 1, 2026-11-07)

**Verification status: `python tools/build_course.py` + `python tools/check_course.py` all PASS (278 pages / 223 lessons / 25 trainings / 19 figures; offline desktop + mobile, quizzes, progress, search).**

### 8.1 §2 content errors — all fixed (9 main errors + 6 secondary)

07-09 event rate changed to 10³ s⁻¹; 07-11 changed to the Mehler kernel; 09-04 added the second London equation and the λ_L value; 14-04 changed to the S-wave shadow zone + PKJKP evidence; 18-04 changed to ENB=1/(4τ), gain 200, formula changed to SNR∝signal/√B; 19-03 changed to η≈L/32000≈30 μm; 07-04 changed to near infrared and points to the time-dependent perturbation lesson; 13-04 added the power-law assumptions and the Eddington luminosity; 03-08 changed to 450 m/s (273 K). Secondary: 12-05 changed to the Q=10 wording; 00-04 external link changed to MIT 18.06 (with a new per-lesson coverage mechanism added); 06-04 declares the (−,+,+,+) signature and adds explicit Christoffel-symbol formulas; 07-06 prerequisites changed so angular momentum is no longer front-loaded; 07-08 singlet description changed to an antisymmetric superposition; 03-02's check-the-boundary segment changed to the ideal-gas conditions of validity.

### 8.2 §3 backbone gaps — 48 new lessons added (175→223)

00 ordinary differential equations; 01 the inertia tensor and rotation in three dimensions, small oscillations and normal coordinates; 02 the wave equation/dispersion/group velocity; 03 the three ensembles and the chemical potential, the MB speed distribution (with reordering: partition function→entropy→Carnot→potentials→ensembles→MB→photons→transport→Ising→Landau); 04 polarization and magnetization, inductance/LC/AC impedance; 05 gratings and thin-film interference, optical cavities and Gaussian beams (05-03 upgraded to the quantitative single-slit intensity); 06 the Lorentz transformation and spacetime diagrams, the complete Schwarzschild line element added to the differential-geometry lesson; 07 time-dependent perturbation theory and Fermi's golden rule, barrier tunneling and finite wells (time-independent perturbation theory moved to before time-dependent); 08 fine structure/Zeeman/21 cm; 09 Bloch's theorem and the reciprocal lattice, phonon heat capacity (Einstein→Debye), the free-electron gas and p-n junctions; 10 the β-decay continuous spectrum and the neutrino; 11 the Standard-Model particle spectrum and Feynman diagrams; 12 magnetic pressure and β, drift motion (both placed before the tokamak lesson), the N_D criterion added to 12-01; 13 magnitudes/distance ladder/telescopes, the dark-energy evidence chain, the life of stars and the compact remnants; 14 plate tectonics and geochronology, magnetosphere/solar wind/space weather; 15 X-ray diffraction and DNA, radiation dose and protection, MRI physics; 16 the special-functions trio, Fourier transforms/convolution/δ; 17 FFT, RK4 and stiff equations, numerical eigenvalues, reproducible workflows; 18 Poisson counting and chi-square tests, SI 2019; 19 the Navier–Stokes derivation, vorticity/circulation/surface tension; 20 bifurcation typology (saddle-node/transcritical/pitchfork/Hopf), the Lorenz equations and the strange attractor; 21 quantitative CHSH, Grover/Deutsch–Jozsa, quantum teleportation and no-cloning, the Bloch sphere added to 21-01; 22 Hartree–Fock and DFT; 23 the transverse β function (Courant–Snyder); 24 convective and radiative heat transfer; 25 the experiments that changed physics (oil drop/scattering/Franck–Hertz).

### 8.3 §5 engineering fixes

The grading tolerance was relaxed to max(0.01, 2%·|e|) and noted in the feedback (check_course's wrong-answer injection changed in step to magnitude-based construction); the lesson-page and checklist-page completion marks were **unified on one key** (the checklist reuses `NN-deep-i`/`NN-j`/`NN-research`; checking syncs both ways); three mapping tweaks in classification-reference.json (gen-ph→[0,25], flu-dyn→[14,19], class-ph→[1,2,3,4]).

### 8.4 §4 system upgrades (round 2 in progress)
- ✅ **Derivation-gap completion mechanism**: the lesson sources gained an optional "key intermediate steps" column, rendered as expandable `<details class="steps-detail">` blocks; filled in for the 12 named lessons (the harmonic-oscillator series solution, the London equations→∇²B, the quantum Hall TKNN chain, laser-cooling fluctuation–dissipation, the GR weak-field solution, the four Carnot steps, the photon density of states, differentiating the partition function, the hydrogen radial solution, the stellar L–M order-of-magnitude derivation, the electromagnetic-wave derivation chain, residues + Jordan's lemma).
- ✅ **Tiered numerical-question mechanism**: a new optional "advanced self-test" column (`题::答案::解答`), rendered as a second interactive quiz, annotated "on the day-1/3/7 reviews, do this question instead to avoid memorizing the answer"; check_course.py now iterates over every quiz of each lesson. Questions were supplied for all 32 deep lessons of fields 03/04/07 (including unit-conversion and multi-step types); the remaining fields will be filled in round by round.
- ✅ **Template-phrase deduplication**: the deep lessons' "before entering the next stage" checklist and the basic lessons' "transfer exercise" lead-in now use 3 rotating variants keyed by lesson hash.
- ✅ **data-key stabilization**: generated lessons now use `NN-{sha1(标题)[:8]}` hash keys, so inserting/reordering lessons no longer misaligns user progress; the checklist page syncs automatically (reusing the same keys).
- ✅ **Dark mode**: kept the CSS-declared `color-scheme: light` (the review's "declare light-only" option).
- Verification: `PASS: 278 pages, 223 quizzes, 25 projects, 19 diagrams` (rendering of both new columns, slug keys, variant distribution, and the advanced self-test interaction were all spot-checked and passed).

### 8.5 Round 3 wrap-up (site-wide coverage complete)
- **Advanced self-tests across the whole site**: a second tiered self-test has been supplied for all **185 deep lessons** (including the first two lessons of fields 19–25), for a site total of **408 interactive self-tests** (223 basic + 185 advanced); fixed the round-2 assembly error in which 32 advanced questions landed in the "intermediate steps" column (25 rows migrated + 14 rows backfilled).
- Verification: `PASS: 278 pages, 223 quizzes…` (the quiz count is a page count); a page-by-page scan confirmed 185/185 deep lessons contain an advanced question, with 0 rows of residual assembly errors.

### 8.6 Overall completion status (against this review's issue list)
| Review item | Status |
|---|---|
| §2 content errors (9 main + 6 secondary) | ✅ all fixed and spot-checked in place |
| §3 P0 backbone gaps per field | ✅ fully covered by 48 new lessons (175→223 lessons) |
| §4.1 derivation gaps | ✅ mechanism + complete intermediate steps for the 12 flagged lessons |
| §4.2/3 tiered self-tests and anti-memorization | ✅ two-question scheme for all 185 deep lessons (a different question at review time) |
| §4.4 grading tolerance | ✅ max(0.01, 2%) |
| §5.1 progress keys | ✅ two-page sync + stable hash keys |
| §5.2 three arXiv mapping items | ✅ fixed |
| §5.3 single-source change discipline | ✅ all changes landed in tools/*.py with a rebuild |
| Dark mode (optional item) | ✅ adopted the "declare light-only" option |
| P1-level expansions (multipole expansion, WKB/CG, magnetic-mirror diagnostics, exoplanets, etc.) | left to the later roadmap; not part of the issue list this review committed to |

## 9. Extension-round log (the "including optional and extended" goal)

### 9.1 Round 4 (this round)
- **All optional engineering items done for real**:
  - Dark mode: a complete `prefers-color-scheme: dark` palette (dark background with light text; dark cards/formulas/tables; interactive SVG figures get a light backing plate to preserve contrast); five page types verified programmatically (bg/fg color sampling, no overflow, no JS errors); screenshot saved to `verification/dark-sample.png`.
  - arXiv mapping additions: `nlin.SI→[2,16,20]`, `hep-lat→[11,17]`; README note on how entry counts are tallied (excluding the 4 methodology points).
- **P1 lessons, first batch (23, 223→246 lessons)** — fields 03/04/05/06/07/16:
  - 03: molecular partition functions and the heat-capacity ladder, equipartition and the virial theorem, the Langevin equation and Brownian motion, the third law/absolute entropy and negative temperature
  - 04: the magnetic vector potential and gauges (including the Aharonov–Bohm effect), electromagnetic momentum and radiation pressure, uniqueness theorems and spherical images
  - 05: Michelson and Fabry–Pérot interferometers, birefringence and wave plates, Fermat's principle/prisms and aberrations
  - 06: Einstein's equation, Kerr black holes and gravitational-wave detection, gravitational lensing
  - 07: the variational method (helium ground state), semiclassical WKB, angular-momentum coupling and Clebsch–Gordan coefficients, the density matrix and composite systems, Slater determinants and exchange energy, Ehrenfest's theorem and wave packets
  - 16: Sturm–Liouville theory, group theory and representations, the Laplace transform, the three classic equations
- Verification: `PASS: 301 pages, 246 quizzes, 25 projects, 19 diagrams`; the mobile viewport fully green after fixing two long-formula line breaks.

### 9.2 Round 5 (goal round 2): all extensions complete
- **P1 second batch (21 lessons)**: 08 (the Stark effect, rovibrational spectroscopy, sub-Doppler/MOT, Voigt broadening, optical pumping and atomic clocks); 09 (magnetic ordering, superfluid helium, BCS, the classical Hall effect, effective mass and holes); 10 (Rutherford scattering, nuclear density saturation, neutron moderation, nuclear astrophysics); 11 (running couplings and grand unification, neutrino oscillations); 12 (Landau damping, diagnostics, magnetic mirrors, O/X-mode wave heating, magnetic reconnection).
- **P1 third batch (17 lessons)**: 13 (binary stars, pulsating Cepheids, accretion/X-rays, exoplanets, inflation, structure growth); 14 (the paleomagnetic dynamo, magnitude statistics, tides, post-glacial rebound, zero-dimensional climate); 15 (Hodgkin–Huxley action potentials, optical tweezers, super-resolution fluorescence, CT/Radon, enzyme kinetics, osmotic pressure and bioelectricity).
- **P1 fourth batch (21 lessons)**: 17 (Metropolis, Richardson, iterative methods/multigrid, root-finding and optimization); 18 (Johnson/shot noise, the t distribution, Bayes); 20 (fractal dimension, KAM, Kuramoto, Duffing); 21 (quantum sensing, entanglement entropy); 22 (femtosecond chemistry, intermolecular forces, chemical equilibrium); 23 (synchrotron oscillations, collective effects); 24 (semiconductor devices, spintronics/metamaterials); 25 (the scientific method).
- **P1 fifth batch + P2 (14 lessons)**: 00 (trigonometric identities); 01 (canonical transformations, elastic continua); 02 (sound radiation/ultrasound/nonlinear acoustics); 19 (low Reynolds number/microfluidics, multiphase flow); 17 (finite elements/spectral methods, DMRG/QMC, HPC/SciML); 20 (complex networks, Turing patterns); 21 (VQE/tomography); 09 (soft matter in depth); 13 (multi-messenger).
- **Advanced self-tests for the introductory lessons**: the build_course template supports optional columns 21/22; all 38 introductory lessons received a second question.
- After fixing two new-column assembly offsets (94 rows migrated + 2 rows patched by hand): **the whole site has 319 lessons × 2 questions = 638 interactive self-tests, 0 lessons missing an advanced question**; `PASS: 374 pages, 319 quizzes, 25 projects, 19 diagrams`.

### 9.3 Final scale
175 → **319 lessons** (+144); interactive self-tests 223 → **638**; the rest unchanged (25 research trainings, 19 interactive figures, 369 direction entries). All items of the original review's §2/§3/§4/§5, and the P1/P2 expansion lists reported by the agents, have been implemented.

## 10. Repository review and fixes (2026-11-13)

Reviewed the generators, authored tables, both frontends, styles, CI, and all numeric question/answer entries; corrected **27 corresponding lessons in both languages**. Existing lesson order and progress keys are preserved. Earlier completion statements describe historical work, not a guarantee against future findings.

Content corrections include variance of an average (σ²/2 for two independent measurements), relative Taylor error (0.67% at 0.2 rad), digital resolution uncertainty (0.02/√12 mm), Gaussian variance addition, the Gibbs N! factor, the conditions for Poisson particle counts, three-dimensional diffusion, coherence-length conversion (2500 μm), α²≈5.3×10⁻⁵, and the inverse half-angle Rutherford ratio (0.0179).

Clarified oscillator selection rules, paraxial interference, perturbative truncations, inertia tensors and axis alignment, rigid-Earth versus Chandler periods, binary radial-velocity amplitudes, Schwarzschild thin-disk efficiency (5.7%), the full P₂ order-parameter range, dispersion potential versus force, NS assumptions, illustrative climate inputs, Richardson error expansions, analytic spectral convergence, DMRG entanglement and sign-free assumptions, and the golden-section retained fraction.

The three-qubit repetition code only corrects one X error and has distance 1 against general quantum errors. Grover's first-peak iteration counts are 12 for N=256 and 78 for N=10⁴. The holography lesson now distinguishes large λ/small curvature from large N/weak string loops and removes the universal viscosity-bound claim. Metamaterial conclusions are restricted to their stated model; the unsupported billion-fold disk-density claim is removed.

Independent calculations support the numeric corrections. Primary references include [NIST uncertainty propagation](https://www.nist.gov/pml/nist-technical-note-1297/nist-tn-1297-appendix-law-propagation-uncertainty), [Rutherford scattering](https://farside.ph.utexas.edu/teaching/plasma/lectures/node36.html), [MIT liquid-crystal order](https://www.mit.edu/~pezeril/wa_files/Thesis.pdf), [NASA Earth wobble](https://core2.gsfc.nasa.gov/MIRROR_www_astro_oma_be/chandwob.html), [NASA Schwarzschild disk model](https://heasarc.gsfc.nasa.gov/docs/software/xspec/manual/node216.html), [IBM error correction](https://quantum.cloud.ibm.com/learning/en/courses/tools-for-quantum-advantage/error-correction-ii), [IBM Grover iteration analysis](https://quantum.cloud.ibm.com/learning/en/courses/fundamentals-of-quantum-algorithms/grover-algorithm/number-of-iterations), [the original large-N holography paper](https://arxiv.org/abs/hep-th/9711200), and [viscosity-bound violations](https://arxiv.org/abs/0712.0805).

Engineering fixes:

- **P1 grading:** the old absolute tolerance 0.01 accepted zero for an expected answer of 0.001. Both editions now use 2% relative tolerance for nonzero answers and exact zero for zero answers.
- **P2 dark readability:** fixed white-on-white numeric inputs, low-contrast buttons, and light text on light SVG canvases; checks require at least 4.5:1 contrast.
- **P2 progress/navigation:** storage and pageshow handlers synchronize live lesson/checklist tabs, including both languages. Language detection uses the document language. Disabled-storage fallback remains usable.
- **P2 generation:** importing the builder no longer writes files. Validation rejects malformed rows, nonfinite answers, misplaced advanced quizzes, duplicate identities, and unknown fields/stages before generation, including under Python optimization.
- **P2 verification:** reconcile both manifests against real paths, progress keys, quiz counts/answers, demos, and language maps; check fragments, duplicate ids, labels, and offline assets; exercise grading boundaries, storage failure, four-tab progress, and an HTTP project prefix.
- **Maintenance:** checks are read-only by default; reports/screenshots require `--write-report`. `--structure-only` needs no browser. Added 24 standard-library regression tests and a CI step. Counts across both editions are **748 pages, 638 lesson pages, 1276 quizzes, and 38 diagrams**; earlier logs mislabeled lesson-page counts as quiz counts.

Commands and results are in `verification/REPORT.en.md`. No lesson-count expansion was attempted in this pass; additions focus on correct reasoning, explicit assumptions, reproducible answers, and maintenance. Automated checks do not establish correctness of every physics statement; the README continues to describe the larger curriculum and problem-set gaps.
