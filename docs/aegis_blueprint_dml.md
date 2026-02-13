# AEGIS — DML‑lite Inference Framework Blueprint

Document role: Scientific specification (normative).
Companion operational guide: `IMPLEMENTATION_GUIDE.md`.
Version target: `v0.1.0`.

AEGIS is an open‑source R research framework focused on **finite-sample reliability of ML-assisted inference**: statistically valid inference when machine learning is used inside a modeling pipeline.

Unlike tools centered on predicted or imputed outcomes, AEGIS follows a **double/debiased ML–style philosophy**:

- enforce **strict out‑of‑fold prediction via cross‑fitting**,
- apply **orthogonal (residualized) score construction** so nuisance estimation error does not corrupt inference,
- provide **valid confidence intervals and p‑values** for target parameters in downstream models, and
- deliver **reproducible diagnostics** that detect leakage, weak signal, or instability.

The project aims to combine **publishable statistical methodology** with **clean, extensible research software** suitable for CRAN release and academic citation.

---

# 0. Quickstart

This document is the **scientific and design specification** for AEGIS. The operational build instructions are in `IMPLEMENTATION_GUIDE.md`.

Minimal reader path (30–45 minutes):

1. Read Section 0.1 (notation) and Sections 3–4 (core method/theory).
2. Read Section 5 (simulation protocol) and Section 6 (empirical protocol).
3. Read Section 8 (API contracts and traceability) to map theory to code/tests.
4. Open `IMPLEMENTATION_GUIDE.md` and execute Phases A–B for package bootstrap.
5. Validate with local checks and toy runs before implementing Phases C–E.

Completion check:

- You can explain what the orthogonal score is and why cross-fitting is required.
- You can identify which package modules implement each theoretical claim.
- You can run the bootstrap package checks described in `IMPLEMENTATION_GUIDE.md`.

## 0.1 Notation and glossary

| Symbol / Term         | Meaning                                                        |
| --------------------- | -------------------------------------------------------------- |
| $W_i=(Y_i,D_i,Z_i)$   | Observation tuple (outcome, target regressor/signal, controls) |
| $\theta_0$            | Low-dimensional target parameter of inferential interest       |
| $\eta_0$              | Nuisance components (possibly high-dimensional/nonparametric)  |
| $\psi(W;\theta,\eta)$ | Score/estimating-equation function                             |
| $J_0$                 | Score Jacobian at $(\theta_0,\eta_0)$                          |
| $\Omega_0$            | Score second-moment matrix                                     |
| $I_k$                 | Held-out index set for fold $k$                                |
| $\hat{\eta}^{(-k)}$   | Nuisance estimate trained outside fold $k$                     |
| OOF                   | Out-of-fold (strictly not trained on the scored observation)   |
| Cross-fitting         | K-fold sample-splitting with OOF nuisance evaluation           |
| Orthogonality         | First-order insensitivity of score moments to nuisance error   |
| Sandwich variance     | $J^{-1}\Omega J^{-T}$ style asymptotic variance estimator      |

---

# 1. Introduction

Flexible machine learning methods are now routinely embedded within statistical estimation pipelines to control for high-dimensional covariates, approximate unknown regression functions, or construct predictive signals. While such integration can substantially reduce bias and improve predictive performance, it also breaks the classical assumptions underlying standard errors, confidence intervals, and hypothesis tests. In particular, data reuse and overfitting induce non-negligible first-order bias, and slow convergence of ML nuisance estimators invalidates conventional plug-in inference.

Recent advances in semiparametric theory—most notably double/debiased machine learning (DML)—show that valid inference can be restored through two key principles: Neyman-orthogonal score construction and sample splitting with cross-fitting. Together, these ideas make estimating equations first-order insensitive to nuisance estimation error and relax empirical-process restrictions that would otherwise preclude flexible learners. Although the theoretical foundations are well established, software that is simultaneously statistically principled, lightweight, extensible, and reproducible remains limited.

This paper introduces AEGIS, an open-source R framework designed to make orthogonal cross-fitted inference accessible to applied researchers while remaining faithful to modern semiparametric theory. AEGIS provides:

- a score-based abstraction for defining estimands,
- automated cross-fitting and orthogonalization,
- heteroskedasticity-robust inference with ML nuisances, and
- built-in diagnostics detecting leakage, weak signal, and instability.

Our goal is not to provide a comprehensive causal-inference platform, but a minimal inference engine that bridges rigorous DML methodology and reproducible applied workflows.

## Contributions

This work makes five primary contributions:

1. Reframes ML-assisted inference as a finite-sample reliability problem and positions AEGIS as a calibrated reliability layer around orthogonal DML engines, rather than as a new estimator theory.
2. Defines a stress-envelope confidence interval based on fold-seed perturbations and provides a weak finite-sample guarantee (nonasymptotic bound and asymptotic conservativeness).
3. Calibrates diagnostics (nuisance-rate, Jacobian conditioning, weak-signal, fold instability) as statistical tests with operating characteristics (FPR/FNR, ROC, P(miss | FAIL)).
4. Conducts an adversarial reliability audit of contemporary DML software (DoubleML, grf-based pipelines, tmle3, and naive ML regression) under aligned estimands and learner parity.
5. Delivers a reproducible research compendium with one-command rebuild, artifact manifests, and theory-to-code traceability.

## Organization of the document

Section 3 introduces the orthogonal score framework and presents partially linear and logistic worked examples.
Section 4 develops the finite-sample reliability theory, including the stress-envelope CI, weak-signal boundary, and diagnostic calibration claims.
Section 5 defines the simulation program and adversarial audit protocol, including the boundary experiment, diagnostic ROC, and fold-instability studies.
Section 6 provides a real-data illustration (secondary evidence).
Section 7 situates AEGIS in related methodological and software literature, emphasizing complementarity with existing DML platforms.
Section 8 defines package API contracts, artifact schemas, and the research-compendium execution contract.
Section 9 provides the risk register, quantitative acceptance criteria, and the minimal publishability checklist.
Section 10 states limitations and future research directions.
Section 11 provides selected references.
Appendix A points to the execution companion document `IMPLEMENTATION_GUIDE.md`.

---

# 2. Scientific goal and contribution

## Core positioning

AEGIS is not positioned as a new estimator. The central scientific object is **finite-sample reliability of ML-assisted inference**. AEGIS provides a calibrated, reproducible reliability layer (diagnostics plus stress-envelope inference) around cross-fitted orthogonal estimators.

AEGIS is designed as a **lightweight, extensible DML-style inference framework** for R:

- Focus: **finite-sample reliability of inference with ML nuisance components**.
- Not focused on: predicted‑outcome correction or label‑imputation frameworks.
- Relationship to ecosystem:
  - Complementary to classical regression and sandwich inference.
  - Distinct from predicted‑outcome IPD‑style packages.
  - Complements existing DML software (DoubleML, grf, tmle3) by providing a diagnostics-driven reliability layer, not new estimator theory.

## Problem

When ML models are trained on the same data later used for statistical inference, naïve standard errors and p‑values become invalid due to:

- overfitting and data reuse,
- selection bias from flexible learners, and
- sensitivity of estimators to nuisance estimation error.

## AEGIS contribution (v0.1)

1. **Cross‑fitted nuisance prediction** ensuring strict out‑of‑sample evaluation.
2. **Orthogonal score construction** reducing sensitivity to nuisance error.
3. **Stress‑envelope confidence intervals** that account for fold‑seed instability, with a weak finite-sample guarantee.
4. **Calibrated diagnostics** with operating characteristics tied to CI under‑coverage (ROC, P(miss | FAIL)).
5. **Adversarial reliability audit** of contemporary DML pipelines under aligned estimands and learner parity.

## Scope narrowing for publication

The manuscript focuses on a single thesis:

> **Finite-sample reliability of cross-fitted orthogonal inference.**

De-emphasize in the main paper:

- CRAN engineering and full API surface details.
- Long risk-register tables and future ecosystem integrations.
- Multi-domain ambitions beyond the core reliability message.

These belong in appendices, a software companion paper, or repository documentation.

## Explicit non-goals

To avoid scope creep, the paper does **not** attempt:

- new causal identification theory,
- new orthogonal score classes,
- deep asymptotic efficiency results, or
- neural-network-specific theory.

---

# 3. Statistical framework and orthogonal score construction

This section presents the formal semiparametric framework underlying AEGIS, using estimating‑equation notation, Neyman orthogonality, and cross‑fitted nuisance estimation. The exposition follows the structure of a publishable semiparametric theory section.

## 3.1 Statistical model and target parameter

Let observations $W_i = (Y_i, D_i, Z_i)$ be independent and identically distributed draws from an unknown distribution $P$ in a nonparametric model. The inferential target is a finite‑dimensional parameter $\theta_0 \in \mathbb{R}^p$, defined by the population moment condition $\mathbb{E}[\psi(W; \theta_0, \eta_0)] = 0$, where $\psi$ is a measurable score function and $\eta_0$ denotes nuisance functions that may be high‑dimensional or nonparametric. Define the score Jacobian

$$
J_0 := \left.\partial_\theta \mathbb{E}[\psi(W; \theta, \eta_0)]\right|_{\theta = \theta_0}.
$$

The statistical task is to construct an estimator $\hat{\theta}$ that is $\sqrt{n}$‑consistent and asymptotically normal while allowing flexible machine‑learning estimation of $\eta_0$.

## 3.2 Neyman orthogonality

The score is assumed to satisfy Neyman orthogonality at the true parameter, which makes the moment condition first‑order insensitive to nuisance perturbations. Formally, for every admissible nuisance perturbation $h$ in tangent set $\mathcal{H}$,

$$
\left.\frac{\partial}{\partial r}\,\mathbb{E}[\psi(W; \theta_0, \eta_0 + r h)]\right|_{r=0} = 0.
$$

This property enables valid inference under comparatively slow convergence rates for machine‑learning estimators.

## 3.3 Cross‑fitted nuisance estimation

To eliminate bias from data reuse, AEGIS employs $K$‑fold cross‑fitting. Let $\{I_k\}_{k=1}^K$ be a partition of $\{1,\dots,n\}$ and let $I_k^c$ denote the training complement. For each fold $k$, nuisance estimators $\hat{\eta}^{(-k)}$ are fit on $I_k^c$ and evaluated on $I_k$. For every observation $i \in I_k$, score evaluation uses $\hat{\eta}^{(-k)}$, ensuring strict out‑of‑fold nuisance prediction.

## 3.4 Estimator definition

Define the cross‑fitted empirical score map

$$
\hat{\Psi}_n(\theta) := \frac{1}{n}\sum_{k=1}^K \sum_{i \in I_k}\psi(W_i; \theta, \hat{\eta}^{(-k)}).
$$

The AEGIS estimator is any solution $\hat{\theta}$ to $\hat{\Psi}_n(\theta)=0$. Linear orthogonal scores yield closed‑form estimators, whereas nonlinear scores are obtained via Newton or score‑root‑finding procedures.

## 3.5 Worked examples

### Partially linear regression

Consider $Y = D\theta_0 + g_0(Z) + \varepsilon$ with $\mathbb{E}[\varepsilon \mid Z, D] = 0$. Defining residualized variables yields an orthogonal score whose solution admits a closed‑form estimator based on cross‑fitted residuals.

### Logistic partially linear model

For binary outcomes with a logistic link, an orthogonal score based on residualized treatment and conditional mean structure yields a $\sqrt{n}$‑consistent estimator obtained via Newton iteration.

# 4. Finite-sample algorithm and asymptotic theory

## 4.1 Finite-sample cross-fitted algorithm

For a user-supplied score $\psi(W;\theta,\eta)$, the procedure is:

1. Partition observations into folds $\{I_k\}_{k=1}^K$.
2. For each fold $k$, fit nuisance learners on $I_k^c$ to get $\hat{\eta}^{(-k)}$.
3. Evaluate out‑of‑fold scores $\psi_i(\theta) = \psi(W_i;\theta,\hat{\eta}^{(-k)})$ for $i \in I_k$.
4. Solve $\hat{\Psi}_n(\theta)=0$ for $\hat{\theta}$ using a closed form (linear case) or Newton updates:

$$
\theta^{(t+1)}=\theta^{(t)}-\hat{J}_n(\theta^{(t)})^{-1}\hat{\Psi}_n(\theta^{(t)}), \quad
\hat{J}_n(\theta)=\partial_\theta \hat{\Psi}_n(\theta).
$$

5. Compute sandwich variance:

$$
\hat{\Sigma}=\hat{J}_n(\hat{\theta})^{-1}\hat{\Omega}\hat{J}_n(\hat{\theta})^{-T}, \quad
\hat{\Omega}=\frac{1}{n}\sum_{k=1}^K \sum_{i\in I_k}\hat{\psi}_i\hat{\psi}_i^\top,
$$

where $\hat{\psi}_i=\psi(W_i;\hat{\theta},\hat{\eta}^{(-k)})$. 6. Report Wald intervals and diagnostics (fold integrity, weak signal, influence, and leakage checks).

## 4.2 Regularity conditions

We impose standard semiparametric conditions:

- **Orthogonality:** $\partial_r \mathbb{E}[\psi(W;\theta_0,\eta_0+r h)]|_{r=0}=0$ for all $h\in\mathcal{H}$.
- **Identification:** $J_0$ is nonsingular in a neighborhood of $\theta_0$.
- **Nuisance rates:** cross‑fitted nuisance errors satisfy product‑rate conditions (e.g., $\|\hat{\eta}_1-\eta_{1,0}\| \cdot \|\hat{\eta}_2-\eta_{2,0}\|=o_p(n^{-1/2})$), which are implied by per‑nuisance rates like $o_p(n^{-1/4})$ in common DML setups.
- **Moments:** $\mathbb{E}\|\psi(W;\theta_0,\eta_0)\|^2<\infty$ and $\Omega_0:=\mathbb{E}[\psi\psi^\top]$ is positive definite.

Operationalization of nuisance-rate assumptions is mandatory in empirical and simulation reports:

For nuisance components $j\in\{1,2\}$ and training fractions $f\in\{0.4,0.6,0.8,1.0\}$, define repeated cross-fitted out-of-fold loss gaps

$$
\Delta_j(f)=\mathrm{OOF\_Loss}_j(f)-\mathrm{OOF\_Loss}_j(1.0).
$$

Estimate learning-curve slopes from

$$
\log(\Delta_j(f)+\epsilon)=c_j-2a_j\log(nf), \quad \epsilon=10^{-6},
$$

and define the product-rate proxy

$$
S:=a_1+a_2.
$$

Interpretation and thresholding rule:

- **PASS:** lower endpoint of the 80% bootstrap CI for $S$ exceeds $0.5$.
- **WARN:** point estimate of $S$ exceeds $0.5$ but the 80% CI overlaps $0.5$.
- **FAIL:** point estimate of $S$ is less than or equal to $0.5$.

`FAIL` invalidates headline inferential claims for that setting. `WARN` requires reporting sensitivity-envelope intervals (Section 4.4) alongside standard Wald intervals.

Calibration requirement (mandatory for publication):

- Report operating characteristics for each diagnostic (false positive rate, false negative rate, ROC/AUC).
- Report $P(\text{CI miss} \mid \text{FAIL})$ and the risk gap $P(\text{miss}\mid \text{FAIL})-P(\text{miss}\mid \text{PASS})$.
- Treat FAIL as a decision-theoretic risk stratifier, not a heuristic flag.

## 4.3 Main theorem

**Theorem 1 (Consistency, asymptotic linearity, and normality).** Under the regularity conditions above,

$$
\sqrt{n}(\hat{\theta}-\theta_0) = -J_0^{-1}\frac{1}{\sqrt{n}}\sum_{i=1}^n \psi(W_i;\theta_0,\eta_0)+ r_n,\quad r_n=o_p(1).
$$

Hence $\hat{\theta}\xrightarrow{p}\theta_0$, and

$$
\sqrt{n}(\hat{\theta}-\theta_0)\xrightarrow{d}\mathcal{N}(0,\Sigma_0),
\quad
\Sigma_0=J_0^{-1}\Omega_0J_0^{-T}.
$$

The influence function is $\phi(W)=-J_0^{-1}\psi(W;\theta_0,\eta_0)$.

## 4.4 Variance estimation and inference

The cross‑fitted sandwich estimator yields asymptotically valid Wald confidence intervals and hypothesis tests for the target parameter.

Inference menu:

- Default: heteroskedasticity-robust sandwich (`HC0` style).
- Optional finite-sample correction: `HC1`/`HC3`.
- Optional dependence-robust mode: cluster-robust sandwich when `cluster_id` is provided.
- Optional resampling inference: multiplier/bootstrap CI and p-value computation for robustness checks.

Finite-sample sensitivity bound (mandatory robustness output):

1. Fit baseline model once to obtain $\hat{\theta}_{\mathrm{base}}$ and $\widehat{SE}$.
2. Re-run the full pipeline $B$ times with independent fold-seed schedules (`B=200` offline full runs, `B=50` CI-lite), producing $\hat{\theta}^{(b)}$.
3. Compute perturbations $d_b=\hat{\theta}^{(b)}-\hat{\theta}_{\mathrm{base}}$.
4. Define stress-envelope radius

$$
B_{0.95}:=\mathrm{quantile}_{0.95}(|d_b|).
$$

5. Report both:
   - Wald CI: $[\hat{\theta}\pm z_{1-\alpha/2}\,\widehat{SE}]$.
   - Stress-envelope CI:
     $$
     \mathrm{CI}_{\text{stress}}
     =
     \left[
     \hat{\theta}-z_{1-\alpha/2}\widehat{SE}-B_{0.95},\;
     \hat{\theta}+z_{1-\alpha/2}\widehat{SE}+B_{0.95}
     \right].
     $$

Stability flag by ratio $B_{0.95}/\widehat{SE}$:

- `Green`: $B_{0.95}\le 0.2\,\widehat{SE}$.
- `Amber`: $0.2\,\widehat{SE}<B_{0.95}\le 0.5\,\widehat{SE}$.
- `Red`: $B_{0.95}>0.5\,\widehat{SE}$.

An analytic sensitivity proxy may be reported as supplementary:

$$
B_{\mathrm{analytic}}:=\|\hat{J}^{-1}\|_{\mathrm{op}}\hat{e}_1\hat{e}_2,
$$

where $\hat{e}_j$ are nuisance-error proxy magnitudes. Release decisions are based on the resampling stress envelope, not solely the analytic proxy.

Weak finite-sample guarantee (target statement):

Under asymptotic linearity, bounded second moments of fold-seed perturbations, and first-order independence between fold perturbations and influence-function noise, there exists $\delta_n \to 0$ such that

$$
\Pr(\theta_0 \in \mathrm{CI}_{\text{stress}}) \ge 1 - \alpha - \delta_n.
$$

Section 4.5 provides a nonasymptotic bound template suitable for empirical validation.

## 4.5 Minimal finite-sample reliability theory (required)

This section converts the stress-envelope and diagnostics from engineering heuristics into weak, reviewer-defensible statistical statements. The goal is finite-sample reliability, not new efficiency theory.

### 4.5.1 Stress-envelope coverage bound (nonasymptotic template)

Let $R_n$ denote the nuisance remainder in the asymptotic expansion of $\hat{\theta}$, and let $\kappa_n$ denote the signal-strength/identification scale (e.g., $\kappa_n := E[V^2]$ in PLR). Let $M_n := \mathbf{1}\{\theta_0 \notin \mathrm{CI}_{\text{stress}}\}$. Assume:

- a remainder control $\Pr(|R_n|/\kappa_n > r_n) \le \rho_n$,
- a stress-quantile estimation error bound $\Pr(|\hat{q}_{0.95}-q_{0.95}|>u_B)\le \delta_B$, with $u_B=O(B^{-1/2})$,
- nominal Wald calibration for the influence-function term at level $\alpha$.

Then there exist constants $C_1,C_2>0$ such that

$$
\Pr(M_n=1) \le \alpha + \rho_n + \delta_B + C_1 r_n + C_2 u_B.
$$

If $\rho_n,\delta_B,r_n,u_B \to 0$, then $\liminf_{n\to\infty}\Pr(\theta_0\in \mathrm{CI}_{\text{stress}})\ge 1-\alpha$.

### 4.5.2 Weak-signal boundary for Wald reliability

Let $\kappa_n := E[V^2] \asymp n^{-\beta}$ and suppose nuisance rates satisfy $\|\hat{g}-g_0\|=O_p(n^{-a})$ and $\|\hat{m}-m_0\|=O_p(n^{-a})$. The scaled remainder behaves as $O_p(n^{-2a+\beta})$, so first-order Wald reliability requires

$$
2a > \frac{1}{2} + \beta \quad \text{(equivalently, } \beta < 2a - \tfrac{1}{2}\text{)}.
$$

This boundary provides a mechanism explanation for weak-signal under-coverage and motivates diagnostics based on $\hat{\kappa}$ and fold-seed instability.

### 4.5.3 Diagnostic risk stratification

Let $M_n$ be the CI-miss event, $E_n$ a latent bad event (large remainder), and $F_n$ a diagnostic FAIL flag. Under detection-quality and risk-separation assumptions with error rates $\eta_0,\eta_1$ and miss risks $p_1>p_0$, a conservative lower bound holds:

$$
\Pr(M_n=1 \mid F_n=1) \ge p_1 - \Delta_n,\quad
\Delta_n := (\eta_0+\eta_1)/\pi_{\min}.
$$

This justifies reporting $P(\text{miss}\mid \text{FAIL})$, risk-gap metrics, and ROC/AUC as primary diagnostic summaries.

# 5. Simulation study design

This section specifies a **journal‑standard Monte Carlo experiment** for evaluating finite‑sample performance of the AEGIS estimator.

## Objectives

The simulation evaluates:

- **Bias** and **RMSE** of point estimates.
- **CI coverage** and **CI length** for Wald, stress-envelope, and comparator intervals.
- **Finite-sample reliability** in weak-signal and misspecification regimes.
- **Diagnostic calibration** (FPR/FNR, ROC/AUC, $P(\text{miss}\mid \text{FAIL})$).
- **Fold-seed instability** and leakage sensitivity.
- **Adversarial audit** of existing DML software under aligned estimands.

with emphasis on regimes in which **machine learning nuisance estimation** and **data reuse** invalidate naïve inference.

---

## Data‑generating processes (DGPs)

We consider two canonical DML benchmarks plus four stress-test extensions.

### DGP 1 — Partially linear regression (PLR)

$Z \sim \mathcal{N}(0, I_p),\quad p \in \{10, 50, 200\}$

$D = m_0(Z) + v,\quad v \sim \mathcal{N}(0, 1)$

$Y = \theta_0 D + g_0(Z) + \varepsilon,\quad \varepsilon \sim \mathcal{N}(0, 1)$

with nonlinear nuisance functions:

$m_0(Z) = \sin(Z_1) + Z_2^2 / 2,$

$g_0(Z) = \cos(Z_1) + Z_3 Z_4.$

Ground truth: $\theta_0 = 1$.

### DGP 2 — Logistic partially linear model

$\Pr(Y = 1 \mid D, Z) = \Lambda(\theta_0 D + g_0(Z)).$

All other components follow the PLR construction.

### DGP 2B — Weak-signal boundary experiment (mandatory)

This semi-oracle design traces the boundary $\beta \approx 2a - 1/2$.

- $Z \in \mathbb{R}^2$, $Z \sim \mathcal{N}(0, I_2)$
- $m_0(Z) = \sin(Z_1) + 0.5 Z_2^2$
- $g_0(Z) = \cos(Z_1) + Z_1 Z_2$
- $\kappa_n := n^{-\beta}$, $U \sim \mathcal{N}(0,1)$, $V := \sqrt{\kappa_n} U$, $D := m_0(Z) + V$
- $\varepsilon \sim \mathcal{N}(0,1)$, $Y := \theta_0 D + g_0(Z) + \varepsilon$, $\theta_0 = 1$

Controlled nuisance perturbations:

- $\hat{m}(Z) = m_0(Z) + n^{-a}\,\xi_m(Z)$
- $\hat{g}(Z) = g_0(Z) + n^{-a}\,\xi_g(Z)$

Construct $\xi_m,\xi_g$ from a fixed feature map and normalize so $(1/n)\sum_i \xi(Z_i)^2 = 1$.

Robustness variants (required):

- heteroskedastic noise $\varepsilon = (1 + 0.5|Z_1|)\eta$, $\eta \sim \mathcal{N}(0,1)$,
- heavy tails $\varepsilon \sim t_5$ scaled to unit variance.

### DGP 3 — Heavy-tail + heteroskedastic PLR

Use the same $m_0(Z), g_0(Z)$ structure as DGP 1 but with

$$
v \sim t_5 / \sqrt{5/3}, \quad
\varepsilon = (0.5 + 0.5|Z_1|)\,u, \quad u \sim t_5 / \sqrt{5/3}.
$$

This DGP tests robustness of standard-error estimation and CI coverage under non-Gaussian tails and conditional heteroskedasticity.

### DGP 4 — Score misspecification stress

Generate outcomes with an interaction omitted from the target score:

$$
Y=\theta_0 D + g_0(Z) + 0.5\,D Z_1 + \varepsilon.
$$

Fit using the baseline partially linear score that omits $DZ_1$. This quantifies sensitivity to orthogonality/model misspecification.

### DGP 5 — Weak-signal regime

Use

$$
D=m_0(Z)+\sigma_v v,\quad \sigma_v\in\{0.15,0.30\},
$$

with DGP 1 outcome structure. This forces near-zero residualized signal variance and stress-tests instability warnings.

### DGP 6 — Cluster dependence

Introduce cluster random effects:

$$
Y_{ic}=\theta_0 D_{ic}+g_0(Z_{ic})+\alpha_c+\varepsilon_{ic},\quad
D_{ic}=m_0(Z_{ic})+\nu_c+v_{ic},
$$

with $c\in\{1,\dots,G\}$ and cluster sizes varying by design. Report both iid-robust and cluster-robust inference to quantify dependence impact.

---

## Estimators compared

Primary estimators for core DGPs:

1. **AEGIS (cross‑fitted orthogonal DML)** with Wald and stress-envelope CIs.
2. **Naïve ML plug‑in regression** (no orthogonalization, no cross‑fitting).
3. **Sample‑splitting only** (no orthogonality).
4. **Oracle estimator** using true nuisance functions (efficiency benchmark).

Comparator arm for weak-signal cells (mandatory):

- Cross-fitted empirical likelihood CI alongside Wald and stress-envelope intervals.

Adversarial audit comparators (mandatory):

1. **DoubleML** under aligned estimands and learner parity.
2. **grf-based orthogonal workflows** (honest forests).
3. **tmle3 / targeted learning pipelines** (aligned estimands).
4. **Naïve ML regression** with sandwich standard errors.

This comparison isolates the contribution of:

- orthogonality
- cross‑fitting
- nuisance estimation error

---

## Machine learning learners

Nuisance functions are estimated with:

- Random forests
- Gradient boosting
- Regularized linear models (lasso / elastic net)

Hyperparameters are tuned via **nested cross‑validation within training folds** to avoid leakage.

For adversarial audits, enforce learner parity and identical tuning budgets across AEGIS and comparator software.

---

## Experimental grid

- **Full paper grid (offline, heavy):**
  - Sample sizes: $n \in \{200, 500, 1000, 5000\}$
  - Dimension: $p \in \{10, 50, 200\}$
  - Repetitions: $R = 1000$ Monte Carlo draws
  - Folds: $K = 5$ cross‑fitting folds
- **CI‑lite grid (automated checks):**
  - Sample sizes: $n \in \{500, 1000\}$
  - Dimension: $p \in \{10, 50\}$
  - Repetitions: $R = 200$
  - Folds: $K = 3$

- **Boundary experiment grid (mandatory):**
  - Sample sizes: $n \in \{300, 500, 1000, 2000, 5000\}$
  - Weak-signal severity: $\beta \in \{0.0, 0.1, \ldots, 1.0\}$
  - Nuisance rates: $a \in \{0.20, 0.25, \ldots, 0.80\}$
  - Repetitions: $R = 500$ (dev), $R = 2000$ (final)

Boundary experiment calibration check (mandatory):

- Estimate achieved nuisance rates $\hat{a}_m,\hat{a}_g$ from log-slope regressions of empirical $L_2$ errors on $\log n$.
- Target criteria: median $|\hat{a}_{\bullet}-a|\le 0.05$ and at least 80% CI coverage of the target $a$ across the grid.

---

## Evaluation metrics

For each estimator, compute:

- Mean bias: $\mathbb{E}[\hat{\theta} - \theta_0]$
- RMSE
- Empirical CI coverage at 95%
- Average CI length
- Nuisance-rate proxy status (`PASS`/`WARN`/`FAIL`) and distribution of $S=a_1+a_2$
- Stress-envelope radius $B_{0.95}$ and stability flag (`Green`/`Amber`/`Red`)
- Jacobian conditioning diagnostics (minimum singular value, condition number)
- Fold-seed instability (distribution of $\hat{\theta}$ across seeds)
- Diagnostic operating characteristics (FPR, FNR, ROC/AUC, $P(\text{miss}\mid \text{FAIL})$)
- Stress-CI bound check rate (fraction of cells where miss rate is below estimated bound)
- Leakage under hyperparameter tuning (explicit audit metric)

Calibration protocol (mandatory):

- Use a calibration set to select diagnostic thresholds and FAIL rules.
- Use a disjoint evaluation set to report final $P(\text{miss}\mid \text{FAIL})$, risk gaps, and ROC/AUC.
- Report sensitivity to stress-quantile replication count $B$ and FAIL-prevalence floor $\pi_{\min}$.

For scalar targets, report relative efficiency:

$$
\mathrm{RE}_m := \frac{\mathrm{Var}(\hat{\theta}_m)}{\mathrm{Var}(\hat{\theta}_{\mathrm{oracle}})},
$$

where $m$ indexes candidate estimators.

## Oracle benchmark definition

The oracle estimator uses the same orthogonal score and fold partition as AEGIS but plugs in true nuisances (e.g., $m_0, g_0$ in PLR). For Monte Carlo replication $b$, compute

$$
\hat{\Sigma}^{(b)}_{\mathrm{oracle}}
=
\left(\hat{J}^{(b)}_0\right)^{-1}
\hat{\Omega}^{(b)}_0
\left(\hat{J}^{(b)}_0\right)^{-T},
$$

with $\hat{J}^{(b)}_0$ and $\hat{\Omega}^{(b)}_0$ evaluated using true nuisance values on simulated data. Report:

- variance ratio $\mathrm{RE}_m$,
- CI length ratio $\mathbb{E}[\text{Length}_m] / \mathbb{E}[\text{Length}_{\mathrm{oracle}}]$,
- and absolute variance gap $\mathrm{Var}(\hat{\theta}_m)-\mathrm{Var}(\hat{\theta}_{\mathrm{oracle}})$.

---

## Expected findings

Based on DML theory, we expect:

- **Naïve ML inference** → severe under‑coverage and instability
- **Sample splitting only** → valid but inefficient
- **Vanilla Wald DML** → under‑coverage in weak‑signal regimes
- **AEGIS stress‑CI** → improved coverage in weak‑signal regimes without catastrophic CI inflation
- **Diagnostics** → meaningful prediction of CI failure (AUC >= 0.7; elevated $P(\text{miss}\mid \text{FAIL})$)
- **Adversarial audit** → AEGIS detects or mitigates failures observed in existing DML software

These results demonstrate the necessity of **orthogonal cross‑fitted inference** when integrating ML into statistical estimation.

---

## Adversarial reliability audit (mandatory)

The paper must include a dedicated section:

**Finite-sample reliability audit of contemporary DML implementations.**

Design requirements:

- Common experimental grid across DoubleML, grf-based orthogonal workflows, tmle3 pipelines, and naive ML baselines.
- Estimand alignment, learner parity, and resampling parity.
- No oracle leakage and explicit tuning-audit logs.
- If an estimand cannot be aligned across software, exclude it from the comparison and document the exclusion explicitly.

Failure modes to measure:

- CI under-coverage in weak-signal regimes.
- Instability across fold seeds.
- Leakage induced by hyperparameter tuning.
- Variance explosions near singular Jacobians.

Required scientific claim:

> Contemporary DML pipelines exhibit finite-sample reliability failures that are detected or mitigated by AEGIS diagnostics and stress-envelope inference.

Conservative framing:

> Under estimand-aligned, learner-neutral, and reproducible protocols, AEGIS improves finite-sample inferential reliability relative to standard DoubleML Wald inference in specific weak-signal regimes, without altering the underlying DML estimator theory.

---

# 6. Real-data empirical application

This section outlines a **reproducible empirical analysis** showing how AEGIS produces valid inference in a realistic applied setting where machine learning is embedded in the estimation pipeline. The empirical example is illustrative; the primary scientific evidence comes from the finite-sample reliability simulations and adversarial audit.

## Application goals

The empirical study is designed to:

- illustrate the full **AEGIS workflow end-to-end**,
- compare naïve and orthogonal inference in real data,
- demonstrate **practical effect sizes, uncertainty, and diagnostics**, and
- provide **fully reproducible research artifacts**.

---

## Fixed benchmark dataset (v0.1)

To make reproducibility auditable, the primary empirical benchmark is fixed to the `Wage` dataset from `ISLR`/`ISLR2` (3,000 observations). We define:

- outcome: $Y=\log(\text{wage})$,
- target regressor: $D=\mathbf{1}\{\text{education} \in \{\text{College Grad}, \text{Advanced Degree}\}\}$ (a binary education indicator),
- controls $Z$: age basis terms, year, race, marital status, job class, health, and insurance variables.

Alternative domains (health/policy) are reserved for secondary robustness checks and are not used for headline claims in v0.1.

---

## Example empirical design (wage regression)

### Data

The benchmark dataset contains:

- hourly wage outcome **Y**,
- education indicator **D** (parameter of interest),
- rich demographic and regional controls **Z**.

The sample size is sufficiently large ($n > 1{,}000$) to support cross‑fitting and ML nuisance estimation.

### Estimation steps

1. **Preprocess data** using a transparent, scripted pipeline.
2. **Estimate nuisance functions** $\mathbb{E}[D \mid Z]$ and $\mathbb{E}[Y \mid Z]$ with ML learners under cross‑fitting.
3. **Run AEGIS orthogonal estimation** for the education effect.
4. **Compute robust confidence intervals** and diagnostics.
5. **Benchmark against naïve regression and sample splitting.**

### Reproducibility contract

All empirical claims in the manuscript are tied to the following artifacts:

- `analysis/empirical/01_prepare_wage.R` (cleaning + feature construction),
- `analysis/empirical/02_fit_models.R` (estimation + diagnostics),
- `analysis/empirical/03_report_tables_figures.R` (reporting outputs),
- `renv.lock` (package version freeze),
- `artifacts/folds_wage.rds` (stored fold assignments),
- `artifacts/session_info.txt` (R/session metadata),
- `artifacts/manifest_wage.json` (schema version, result version, seed schedule, runtime controls),
- `artifacts/provenance_hashes_wage.json` (hashes for data snapshot, folds, learner specs, tuned hyperparameters, and output tables).

Random seed policy: set a master seed (`20260210`) and persist derived fold seeds in artifacts.

---

## Reporting standards

The empirical section should include:

- Point estimates and **95% confidence intervals**
- Comparison table across estimators
- Diagnostic summaries (fold balance, residual variance, influence)
- Sensitivity to learner choice and fold count

All results must be **fully reproducible** by executing the three scripts above, in order, under the locked environment (or via `analysis/run_all.R`).

The report must additionally include:

- nuisance-rate proxy status (`PASS`/`WARN`/`FAIL`) with $S$ and CI,
- stress-envelope CI and stability flag,
- manifest/provenance hash verification status.

---

## Expected contribution of the application

The real‑data example demonstrates that:

- naïve ML‑assisted regression can yield **misleading certainty**,
- orthogonal cross‑fitted inference changes **statistical conclusions**, and
- AEGIS provides a **practical, reproducible solution** for applied researchers.

## Comparator and external-domain benchmark expansion (v0.2+)

v0.1 keeps one fixed benchmark for auditability. Starting in v0.2, add a benchmark pack with:

- one policy-facing dataset with plausible clustered dependence,
- one high-dimensional biomedical-style dataset,
- comparator runs against major DML libraries where estimands align (e.g., DoubleML, grf, econml wrappers via scripted bridges),
- a harmonized reporting table for estimate, SE, CI coverage proxy, runtime, and reproducibility diagnostics.

---

# 7. Related work

This section situates AEGIS within the broader literature on semiparametric inference, double/debiased machine learning (DML), high‑dimensional statistics, and contemporary software ecosystems for valid post‑machine‑learning uncertainty quantification. The goal is to clarify both the **intellectual lineage** of AEGIS and the **methodological gap** it is designed to fill.

## Double/debiased machine learning and orthogonal scores

A growing body of work in semiparametric statistics shows that valid inference for low‑dimensional parameters can be retained in the presence of high‑dimensional or nonparametric nuisance structure through **Neyman‑orthogonal score functions** combined with **sample splitting and cross‑fitting** (Neyman, 1959; Chernozhukov et al., 2018). Foundational contributions in this direction establish that orthogonality removes first‑order sensitivity to nuisance estimation error, while cross‑fitting relaxes empirical‑process conditions that would otherwise restrict the use of flexible machine‑learning learners (Belloni, Chernozhukov, and Hansen, 2014; Chernozhukov et al., 2018). These ideas yield $\sqrt{n}$‑consistent and asymptotically normal estimators under comparatively weak convergence‑rate requirements for nuisance components and form the theoretical backbone of modern DML methodology.

AEGIS adopts this orthogonal‑score paradigm as its core inferential engine, but shifts emphasis from existence results to **reproducible applied implementation**. Whereas much of the DML literature focuses on efficiency bounds, causal identification, or asymptotic optimality, AEGIS concentrates on the **practical reliability of uncertainty quantification** when machine‑learned nuisance functions are embedded in routine regression‑type analyses. In this sense, AEGIS operationalizes established theory within a deliberately minimal, software‑forward framework.

## High‑dimensional and semiparametric inference

Parallel developments in high‑dimensional statistics address inference after regularization, post‑selection adjustment, and debiasing of penalized estimators (Zhang and Zhang, 2014; van de Geer et al., 2014; Javanmard and Montanari, 2014). Debiased lasso–type procedures, post‑selection inference frameworks, and related correction methods provide valid uncertainty quantification under structural assumptions such as sparsity, compatibility conditions, or restricted eigenvalue properties. While powerful in their respective domains, these approaches are often **estimator‑specific** and rely on assumptions that may not hold for modern nonlinear machine‑learning learners.

Orthogonal score–based DML methods instead provide a **model‑agnostic route to inference**, permitting the use of random forests, boosting, neural networks, or other flexible learners without explicit structural constraints on the nuisance representation. AEGIS complements this strand of work by supplying a **lightweight implementation layer** that translates semiparametric guarantees into workflows directly usable in empirical research.

## Software ecosystems for ML‑assisted inference

Several contemporary software platforms implement components of semiparametric or causal DML methodology, frequently centered on treatment‑effect estimation, targeted learning, or domain‑specific causal estimands (DoubleML, grf, tmle3, econml). Other tools address inference with predicted or imputed outcomes, while general machine‑learning frameworks emphasize prediction accuracy rather than post‑estimation validity. As a result, the ecosystem remains **fragmented across goals**—causal estimation, prediction, or theory demonstration—rather than unified around routine regression‑style inference with machine‑learned nuisances.

AEGIS occupies a distinct position within this landscape. It targets **general low‑dimensional parameters** rather than exclusively causal estimands, treats **orthogonal cross‑fitted inference as the default computational primitive**, and integrates **finite‑sample diagnostics**—including leakage detection, weak‑signal assessment, and influence stability—directly into the estimation object. This combination of scope, minimality, and reproducibility differentiates AEGIS from both causal‑specific DML platforms and prediction‑oriented machine‑learning toolchains.

## Contribution relative to existing work

Taken together, existing theory establishes the _possibility_ of valid inference with machine‑learned nuisance functions, yet practical implementations remain dispersed across methodological traditions and software environments. AEGIS contributes by providing:

- a **unified score‑based interface** spanning linear and generalized linear inferential targets;
- **default orthogonal cross‑fitted estimation** with sandwich‑robust uncertainty quantification;
- **diagnostic tooling** that exposes common ML‑induced inferential failure modes in finite samples; and
- a **minimal, reproducible R implementation** designed for extension, replication, and applied methodological research.

Accordingly, AEGIS should be interpreted not as a replacement for semiparametric efficiency theory, causal‑inference frameworks, or high‑dimensional debiasing methods, but as a **bridging layer** that renders modern DML principles operational within everyday statistical practice.

Recommended framing sentence:

> AEGIS complements existing DML software such as DoubleML by providing a diagnostics-driven, reproducible reliability layer for finite-sample inference, rather than introducing new orthogonal estimators or asymptotic theory.

---

# 8. API contracts and traceability

This section defines concrete interfaces and connects statistical claims to implementation and validation artifacts.

## 8.1 Public API contracts (v0.1)

| Function               | Required inputs                                                                                     | Output contract                                                                                                     | Determinism contract                                       | Failure behavior                                            |
| ---------------------- | --------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------- | ----------------------------------------------------------- |
| `aegis_spec()`         | learner, target, strategy; optional nuis/controls                                                   | S3 `aegis_spec` object with validated fields                                                                        | no RNG use                                                 | error on missing/invalid components                         |
| `strategy_crossfit()`  | integer `v >= 2`, optional repeats, optional `seed`, optional `parallel_backend`, optional `n_jobs` | S3 strategy object with fold settings and backend metadata                                                          | deterministic given explicit seed and fixed backend config | error on invalid `v` or backend config                      |
| `learner_base()`       | `fit_fun`, `predict_fun` callables                                                                  | learner wrapper with fit/predict hooks                                                                              | deterministic if learner+seed deterministic                | error on non-function arguments                             |
| `nuis_spec()`          | nuisance learner declarations for outcome/signal                                                    | nuisance specification object                                                                                       | deterministic metadata object                              | error on missing nuisance entries                           |
| `target_lm()`          | formula with target nuisance regressor                                                              | target object with LM tag                                                                                           | deterministic metadata object                              | error on malformed formula                                  |
| `target_glm()`         | formula and family                                                                                  | target object with GLM tag                                                                                          | deterministic metadata object                              | error on invalid family                                     |
| `artifact_schema()`    | optional `schema_version`                                                                           | canonical JSON-schema-like artifact spec                                                                            | deterministic static object                                | error on unknown schema version                             |
| `validate_artifacts()` | fit object or artifact directory                                                                    | validation report with pass/fail and violations                                                                     | deterministic function of artifacts                        | error on unreadable/malformed artifacts                     |
| `provenance_digest()`  | canonicalized data snapshot, folds, learner specs, tuned hyperparameters, runtime controls          | named hash map for provenance fields                                                                                | deterministic under canonical serialization                | error on unsupported object class                           |
| `aegis_fit()`          | spec, data, controls (including `seed`, runtime budget, sensitivity repetitions)                    | S3 `aegis_fit` with estimates, SEs, diagnostics, artifacts, `schema_version`, `result_version`, `provenance_hashes` | deterministic under fixed seed and deterministic learners  | error/warning on convergence, leakage, or schema violations |
| `summary.aegis_fit()`  | fit object                                                                                          | compact inferential + diagnostic summary                                                                            | deterministic function of fit object                       | error on malformed fit object                               |
| `confint.aegis_fit()`  | fit object, confidence level                                                                        | CI endpoints from robust variance                                                                                   | deterministic function of fit object                       | warning/error if SE unavailable                             |

## 8.2 Core invariants

- Every scored observation must use nuisance models trained on disjoint data.
- Fold assignment, master seed, and derived fold/repetition seeds must be stored in fit artifacts.
- Reported `theta`, `se`, and `vcov` must be algebraically consistent.
- Diagnostics must be first-class outputs, not side effects.
- Artifact bundles must validate against the declared `schema_version`.
- Every fit artifact bundle must include a machine-readable manifest with `result_version`.
- Provenance hashes must be stored for data snapshot, fold assignment, learner declarations, tuned hyperparameters, and reporting outputs.
- Parallel execution must use deterministic RNG substreams indexed by `(repeat_id, fold_id, learner_id)`.
- Hyperparameter tuning must occur strictly inside each training complement fold to prevent leakage.

## 8.3 Traceability matrix

| Scientific claim                         | Primary module(s)                                                        | Required tests                                       | Required artifact(s)                                         |
| ---------------------------------------- | ------------------------------------------------------------------------ | ---------------------------------------------------- | ------------------------------------------------------------ |
| Strict out-of-fold nuisance evaluation   | `R/crossfit.R`, `R/nuisance.R`                                           | `test-crossfit-integrity.R`                          | `artifacts/folds_*.rds`                                      |
| Orthogonal score implementation          | `R/inference_lm.R`, `R/inference_glm.R`                                  | `test-lm-orthogonal.R`, `test-glm-orthogonal.R`      | score residual diagnostics                                   |
| Nuisance-rate proxy and thresholding     | `R/diagnostics_rates.R`                                                  | `test-rates-proxy.R`                                 | `diagnostics_rates.csv`                                      |
| Finite-sample stress envelope            | `R/diagnostics_sensitivity.R`                                            | `test-sensitivity-envelope.R`                        | `diagnostics_sensitivity.csv`                                |
| Robust uncertainty quantification        | `R/inference_*.R`, `R/methods.R`                                         | CI/SE sanity tests                                   | `estimates.csv`, `diagnostics.csv`                           |
| Reproducibility under fixed seed         | `R/aegis_fit.R`                                                          | `test-reproducibility.R`, `test-parallel-rng.R`      | `session_info.txt`, `renv.lock`, `artifacts/manifest_*.json` |
| Schema/provenance integrity              | `R/artifacts.R`                                                          | `test-artifact-schema.R`, `test-provenance-hashes.R` | `artifacts/provenance_hashes_*.json`                         |
| Coverage/efficiency claims in manuscript | `analysis/sim/*.R`                                                       | simulation regression tests                          | `summary_metrics.csv`, figures/tables                        |
| Diagnostic calibration claims            | `analysis/sim/calibration_study.R`, `analysis/figures/figC_roc.R`        | calibration sanity tests                             | `diagnostics_operating_chars.csv`                            |
| Weak-signal boundary claims              | `analysis/sim/boundary_experiment.R`, `analysis/figures/figB_boundary.R` | boundary regression tests                            | `boundary_summary.csv`                                       |
| Adversarial audit claims                 | `analysis/sim/adversarial_benchmark.R`, `analysis/figures/figE_pareto.R` | comparator parity tests                              | `adversarial_audit_summary.csv`                              |

## 8.4 Artifact schema and provenance minimum fields

Every empirical and simulation run must write a manifest with at least:

- `schema_version`, `result_version`, `blueprint_version`,
- wall-clock timestamp and runtime profile,
- master seed and derived fold/repetition seeds,
- strategy configuration (`K`, repeats, backend, workers),
- learner declarations and tuned hyperparameters,
- hashes for input data snapshot and key output tables/figures,
- validation status from `validate_artifacts()`.

## 8.5 Research compendium execution contract (mandatory)

The repository must support one-command rebuild of all figures and tables.

Recommended minimal structure:

```
AEGIS/
  R/
  analysis/
    sim/
      boundary_experiment.R
      adversarial_benchmark.R
      calibration_study.R
      schema.md
    figures/
      figA_weak_signal.R
      figB_boundary.R
      figC_roc.R
      figD_instability.R
      figE_pareto.R
    tables/
      table1_coverage.R
      table2_diagnostics.R
      table3_reproducibility.R
  artifacts/
  paper/
  _targets.R
```

Execution guarantees:

- One-command rebuild: `Rscript -e "targets::tar_make()"`.
- Deterministic randomness with a documented seed hierarchy and persisted fold seeds.
- `renv.lock` pins package versions; `sessionInfo()` stored in artifacts.
- Figure/table scripts must read artifacts only and perform no new simulation.

## 8.6 Core simulation artifact outputs (required)

Each simulation program must write a minimal, reviewer-auditable bundle:

- Boundary experiment:
  - `artifacts/sim/boundary_results.rds`
  - `artifacts/sim/boundary_summary.csv`
  - `artifacts/sim/boundary_manifest.json`
- Calibration study:
  - `artifacts/sim/calibration_results.rds`
  - `artifacts/sim/diagnostics_operating_chars.csv`
  - `artifacts/sim/calibration_manifest.json`
- Adversarial audit:
  - `artifacts/sim/adversarial_results.rds`
  - `artifacts/sim/adversarial_audit_summary.csv`
  - `artifacts/sim/adversarial_manifest.json`

---

# 9. Risk register and quantitative acceptance criteria

## 9.1 Risk register

| Risk                                  | Trigger                                           | Impact                                 | Mitigation                                                           | Fallback                                                 |
| ------------------------------------- | ------------------------------------------------- | -------------------------------------- | -------------------------------------------------------------------- | -------------------------------------------------------- |
| Data leakage                          | in-fold prediction reuse                          | invalid inference                      | strict fold metadata checks                                          | fail-fast and block release                              |
| Hyperparameter leakage                | tuning uses any held-out fold observations        | optimistic nuisance fit, invalid CI    | nested CV strictly inside training complements, fold-audit logs      | invalidate run, re-tune with corrected splits            |
| Orthogonality mis-specification       | score implementation error or omitted score terms | first-order bias, coverage failure     | symbolic/numerical score checks, misspecification stress DGP         | mark estimand unsupported until score fixed              |
| Near-singular Jacobian                | weak identification or unstable design            | exploding variance, unstable estimates | Jacobian conditioning diagnostics, ridge-stabilized solve warnings   | report unsupported regime                                |
| Small-sample variance underestimation | aggressive asymptotics at low $n$                 | anti-conservative inference            | HCk and bootstrap/multiplier checks, stress-envelope CI              | require robust interval as primary                       |
| Diagnostic miscalibration             | FAIL/WARN thresholds not tied to coverage         | false reassurance or over-warning      | calibration study with ROC/AUC and $P(\text{miss}\mid \text{FAIL})$  | treat diagnostics as warnings only                       |
| Weak signal                           | near-zero residualized nuisance variance          | unstable SE/CI                         | weak-signal diagnostics + warning threshold                          | report as unsupported regime                             |
| GLM non-convergence                   | Newton iterations exceed cap                      | missing estimates                      | line search, bounded steps, better init                              | switch to robust root solver                             |
| Parallel RNG drift                    | backend-dependent RNG behavior                    | irreproducible parallel runs           | deterministic substream mapping and parity tests vs sequential       | disable parallel mode for release artifact               |
| Non-determinism                       | inconsistent RNG handling                         | irreproducible results                 | single master seed + persisted fold seeds                            | quarantine failing tests/artifacts                       |
| Memory pressure                       | large learners or repeated resampling             | OOM failures, partial artifacts        | memory budget checks, checkpointed artifact writes                   | reduce learner set / batch size                          |
| CRAN/runtime constraints              | long checks or heavy dependencies                 | blocked package release                | CI-lite benchmark profile, optional heavy dependencies               | split heavyweight analyses into external pipeline        |
| Runtime blow-up                       | nested tuning on large grid                       | delayed release                        | cap grid for CI pipeline, parallelize batch runs                     | staged benchmark runs                                    |
| Untrusted custom learner behavior     | arbitrary user learner code                       | execution safety risk                  | explicit trust model, restricted interfaces, input/output validation | disable custom learner mode in reproducible release runs |

## 9.2 Quantitative acceptance criteria (v0.1)

| Category                 | Metric                                                                       | Threshold                                                                                                                                                            |
| ------------------------ | ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Coverage validity        | Empirical 95% CI coverage for AEGIS at $n \ge 500$                           | between 93% and 97% on core DGPs                                                                                                                                     |
| Stress coverage          | Empirical 95% CI coverage on heavy-tail/heteroskedastic and weak-signal DGPs | at least 90% with robust interval mode                                                                                                                               |
| Stress-CI bound check    | Stress-CI miss rate vs estimated nonasymptotic bound                         | bound holds in >= 90% of primary grid cells                                                                                                                          |
| Boundary sharpness       | Coverage separation across $\psi = 2a - \tfrac{1}{2} - \beta$                | median coverage for $\psi > 0.10$ >= 0.93 and for $\psi < -0.10$ <= 0.90                                                                                             |
| Diagnostic calibration   | ROC/AUC and risk stratification                                              | AUC >= 0.7 and $P(\text{miss}\mid \text{FAIL})$ >= 0.7 in stress regimes                                                                                             |
| Efficiency               | Average CI length vs sample-split                                            | AEGIS mean CI length <= 0.90 \* sample-split in >= 70% of grid cells                                                                                                 |
| Bias control             | Absolute bias of AEGIS vs naive                                              | AEGIS absolute bias <= naive in >= 80% of grid cells                                                                                                                 |
| Adversarial audit        | Coverage improvement vs DoubleML in weak-signal regimes                      | AEGIS coverage >= DoubleML in >= 70% of pre-registered weak-signal cells on the primary grid, with CI length ratio <= 1.5 (extreme-stress cells reported separately) |
| Nuisance-rate proxy      | Product-rate proxy $S=a_1+a_2$                                               | lower 80% CI endpoint > 0.5 in >= 80% of core grid cells                                                                                                             |
| Sensitivity stability    | Stress-envelope ratio $B_{0.95}/\widehat{SE}$                                | median <= 0.5 and `Red` rate <= 10% on core grid                                                                                                                     |
| Identification stability | Jacobian conditioning diagnostics                                            | min singular value > 1e-6 and condition number < 1e6 in >= 95% of core runs                                                                                          |
| Convergence              | GLM fit convergence rate                                                     | >= 99% successful convergences                                                                                                                                       |
| Leakage control          | Fold-integrity failures                                                      | exactly 0 tolerated                                                                                                                                                  |
| Artifact contract        | Schema validation success                                                    | 100% pass for release artifacts                                                                                                                                      |
| Provenance completeness  | Required provenance hashes present                                           | 100% required fields present                                                                                                                                         |
| Parallel reproducibility | sequential vs parallel parity under deterministic learners                   | exact equality on scalar summaries                                                                                                                                   |
| Reproducibility          | Hash/summary equality across two reruns with fixed seed                      | exact match on tables and scalar metrics                                                                                                                             |
| Testing                  | Local test suite pass rate                                                   | 100% pass, 0 flaky failures across 3 consecutive runs                                                                                                                |

## 9.3 Minimal publishability checklist (mandatory evidence bundle)

Required figures (exact set of five):

- Figure A: Weak-signal coverage failure of vanilla DML.
- Figure B: Boundary heatmap (beta vs a) with $\beta = 2a - 1/2$ overlay.
- Figure C: Diagnostic ROC for CI failure prediction.
- Figure D: Fold-seed instability distribution.
- Figure E: Coverage vs CI length trade-off (AEGIS vs DoubleML).

Required tables (exact set of three):

- Table 1: Coverage summary across the DGP grid (DoubleML Wald, AEGIS Wald, AEGIS stress-CI).
- Table 2: Diagnostic operating characteristics (FPR, FNR, AUC, $P(\text{miss}\mid \text{FAIL})$).
- Table 3: Reproducibility and instability metrics (fold-seed variance, disagreement rate, $\hat{\kappa}$ summaries).

Falsification rule (critical for honesty):

If Figures A–E do not show the expected qualitative behavior, the methodological claim is not supported. In that case, the correct outcome is a software-focused publication rather than a methodological one.

---

# 10. Limitations and future research directions

Current limitations:

- no automatic causal identification layer (users must supply identification arguments externally),
- asymptotic guarantees are pointwise and may degrade in weak-signal or small-$n$ settings,
- dependence structures (clustered, panel, time series) are not first-class in v0.1,
- computational cost can be high under nested tuning and many folds,
- security hardening for untrusted custom learners is limited in v0.1,
- multi-domain and cross-library comparator evidence is not headline in v0.1.

Near-term research priorities:

- cluster-robust and cross-sectional dependence extensions,
- bootstrap or multiplier inference with validated finite-sample behavior,
- nuisance-rate proxy calibration and stress-envelope diagnostics in default reports,
- schema-versioned artifacts with formal validation and provenance hashing,
- heavy-tail, misspecification, weak-signal, and dependence stress-test simulation battery,
- reproducible comparator benchmarking against major DML libraries,
- adaptive fold and learner-selection policies with guardrails against leakage,
- expansion to additional semiparametric estimands beyond LM/GLM targets.

## Deferred by Scope (non-blocking)

The following items are explicitly deferred and are not release blockers for v0.x:

- **Approximate cross-fitting:** deferred because it can violate strict out-of-fold invariants and weaken inferential guarantees.
- **Automatic orthogonality verification:** only partially automatable in a generic score interface; template-specific checks are preferred in v0.x.
- **Automatic score construction:** treated as long-horizon methodological research rather than a near-term product requirement.
- **Security hardening for untrusted custom learners:** remains a follow-up hardening track beyond baseline trust-model controls.
- **Python bindings and GPU acceleration:** ecosystem/performance extensions that are non-blocking for core inferential validity.
- **R-first scope:** intentional positioning for the initial release line, not a defect.
- **New causal identification theory:** explicitly out of scope for the paper.
- **New orthogonal score classes or deep efficiency theory:** explicitly out of scope.
- **Neural-network-specific theory:** explicitly out of scope.

Comparator and external-domain expansion is tracked as planned follow-up in Section 6 (`Comparator and external-domain benchmark expansion (v0.2+)`).

---

# 11. Selected references

- Belloni, A., Chernozhukov, V., and Hansen, C. (2014). Inference on treatment effects after selection among high-dimensional controls. _Review of Economic Studies_.
- Chernozhukov, V., Chetverikov, D., Demirer, M., Duflo, E., Hansen, C., Newey, W., and Robins, J. (2018). Double/debiased machine learning for treatment and structural parameters. _The Econometrics Journal_.
- Javanmard, A., and Montanari, A. (2014). Confidence intervals and hypothesis testing for high-dimensional regression. _Journal of Machine Learning Research_.
- Neyman, J. (1959). Optimal asymptotic tests of composite statistical hypotheses. In _Probability and Statistics_.
- van de Geer, S., Buhlmann, P., Ritov, Y., and Dezeure, R. (2014). On asymptotically optimal confidence regions and tests for high-dimensional models. _Annals of Statistics_.
- van der Laan, M., and Rose, S. (2011). _Targeted Learning_. Springer.
- Zhang, C.-H., and Zhang, S. S. (2014). Confidence intervals for low-dimensional parameters in high-dimensional linear models. _Journal of the Royal Statistical Society: Series B_.
- Software comparators: DoubleML, grf, tmle3, econml (project documentation and package papers).

---

# Appendix A. Implementation companion document

The operational, step-by-step package creation blueprint has been split into:

`IMPLEMENTATION_GUIDE.md`

Mapping:

- Environment/bootstrap runbook: `IMPLEMENTATION_GUIDE.md` Phase A
- Minimal compilable package scaffold: `IMPLEMENTATION_GUIDE.md` Phase B
- First real DML implementation: `IMPLEMENTATION_GUIDE.md` Phase C
- Experimental pipeline: `IMPLEMENTATION_GUIDE.md` Phase D
- Release execution checklist: `IMPLEMENTATION_GUIDE.md` Phase E

---

# Appendix B. Scientific identity

AEGIS should be understood as:

> **A minimal, extensible DML‑style inference engine for R**

bridging:

- modern machine learning,
- semiparametric statistical theory, and
- reproducible research software.

The first publication will focus on:

- statistical validity under ML reuse,
- efficiency vs. sample splitting, and
- practical usability for applied researchers.

---

_End of DML‑aligned blueprint._
