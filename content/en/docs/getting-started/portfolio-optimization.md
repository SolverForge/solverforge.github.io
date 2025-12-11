---
title: "Portfolio Optimization"
linkTitle: "Portfolio Optimization"
icon: fa-brands fa-python
date: 2025-12-10
weight: 15
description: "A comprehensive quickstart guide to understanding and building intelligent stock portfolio optimization with SolverForge"
categories: [Quickstarts]
tags: [quickstart, python]
---

{{% pageinfo %}}
A comprehensive quickstart guide to understanding and building intelligent stock portfolio optimization with SolverForge. Learn optimization concepts while exploring a working codebase that demonstrates real-world finance applications.
{{% /pageinfo %}}

---

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [The Problem We're Solving](#the-problem-were-solving)
4. [Understanding the Data Model](#understanding-the-data-model)
5. [How Optimization Works](#how-optimization-works)
6. [Writing Constraints: The Business Rules](#writing-constraints-the-business-rules)
7. [The Solver Engine](#the-solver-engine)
8. [Web Interface and API](#web-interface-and-api)
9. [Making Your First Customization](#making-your-first-customization)
10. [Advanced Constraint Patterns](#advanced-constraint-patterns)
11. [Testing and Validation](#testing-and-validation)
12. [Quick Reference](#quick-reference)

---

## Introduction

### What You'll Learn

This guide walks you through a complete stock portfolio optimization application built with **SolverForge**, a constraint-based optimization framework. You'll learn:

- How to model **investment decisions** as optimization problems
- How to express **diversification rules** as constraints that guide the solution
- How optimization algorithms find high-quality portfolios automatically
- How to customize the system for your specific investment strategies

**No optimization or finance background required** — we'll explain both optimization and finance concepts as we encounter them in the code.

> **Architecture Note:** This guide uses the "fast" implementation pattern with dataclass domain models and Pydantic only at API boundaries. For the architectural reasoning behind this design, see [Dataclasses vs Pydantic in Constraint Solvers](/blog/technical/python-constraint-solver-architecture/).

### Prerequisites

- Basic Python knowledge (classes, functions, type annotations)
- Familiarity with REST APIs
- Comfort with command-line operations

### What is Portfolio Optimization?

Traditional portfolio selection: You write explicit rules like "pick the 20 stocks with highest predicted returns."

**Constraint-based portfolio optimization**: You describe what a good portfolio looks like (diversified, high-return, exactly 20 stocks) and the solver figures out which specific stocks to select.

Think of it like describing the ideal portfolio characteristics and having a computer try millions of combinations per second to find the best fit.

### Finance Concepts (Quick Primer)

| Term | Definition | Example |
|------|------------|---------|
| **Portfolio** | Collection of investments you own | 20 stocks |
| **Weight** | Percentage of money in each investment | 5% per stock (equal weight) |
| **Sector** | Industry category | Technology, Healthcare, Finance, Energy |
| **Predicted Return** | Expected profit/loss percentage | 12% means $12 profit per $100 invested |
| **Diversification** | Spreading risk across sectors | Don't put all eggs in one basket |

---

## Getting Started

### Running the Application

1. **Download and navigate to the project directory:**
   ```bash
   git clone https://github.com/SolverForge/solverforge-quickstarts
   cd ./solverforge-quickstarts/fast/portfolio-optimization-fast
   ```

2. **Create and activate virtual environment:**
   ```bash
   python -m venv .venv
   source .venv/bin/activate  # On Windows: .venv\Scripts\activate
   ```

3. **Install the package:**
   ```bash
   pip install -e .
   ```

4. **Start the server:**
   ```bash
   run-app
   ```

5. **Open your browser:**
   ```
   http://localhost:8080
   ```

You'll see a portfolio optimization interface with stocks, sectors, and a "Solve" button. Click it and watch the solver automatically select the optimal stocks while respecting diversification rules.

### File Structure Overview

```
fast/portfolio-optimization-fast/
├── src/portfolio_optimization/
│   ├── domain.py              # Data classes (StockSelection, PortfolioOptimizationPlan)
│   ├── constraints.py         # Business rules (90% of customization happens here)
│   ├── solver.py              # Solver configuration
│   ├── demo_data.py           # Sample stock data with ML predictions
│   ├── rest_api.py            # HTTP API endpoints
│   ├── converters.py          # REST ↔ Domain model conversion
│   ├── json_serialization.py  # JSON helpers
│   └── score_analysis.py      # Score breakdown DTOs
├── static/
│   ├── index.html             # Web UI
│   └── app.js                 # UI logic and visualization
├── scripts/
│   └── comparison.py          # Greedy vs Solver comparison
└── tests/
    ├── test_constraints.py    # Unit tests for constraints
    └── test_feasible.py       # Integration tests
```

**Key insight:** Most business customization happens in `constraints.py` alone. You rarely need to modify other files.

---

## The Problem We're Solving

### The Investment Challenge

You have **$100,000** to invest and must select **20 stocks** from a pool of candidates. Each stock has an **ML-predicted return** (e.g., "Apple is expected to return 12%").

**Hard constraints** (must be satisfied):
- Select exactly 20 stocks
- No sector can exceed 25% of the portfolio (max 5 stocks per sector)

**Soft constraints** (preferences to optimize):
- Maximize total expected return (pick stocks with highest predictions)

### Why Use a Constraint Solver?

For this simplified quickstart (Boolean selection with sector limits), a well-implemented greedy algorithm can find near-optimal solutions. So why use a constraint solver?

**1. Declarative vs Imperative:** With constraints, you describe *what* you want, not *how* to achieve it. Adding a new rule is one function, not a rewrite of your algorithm.

**2. Constraint Interactions:** As constraints multiply, greedy logic becomes brittle. Consider adding:
- Minimum 2 stocks per sector (diversification floor)
- No more than 3 correlated stocks together
- ESG score requirements

Each new constraint in greedy code means more `if/else` branches and edge cases. In a constraint solver, you just add another constraint function.

**3. Real-World Complexity:** Production portfolios have weight optimization (not just in/out), correlation matrices, risk budgets, and regulatory requirements. These create solution spaces where greedy approaches fail.

---

## Understanding the Data Model

Let's examine the core classes that model our problem. Open `src/portfolio_optimization/domain.py`:

### Domain Model Architecture

This quickstart separates domain models (dataclasses) from API models (Pydantic):

- **Domain layer** (`domain.py` lines 32-169): Pure `@dataclass` models for solver operations
- **API layer** (`domain.py` lines 268-307): Pydantic `BaseModel` classes for REST endpoints
- **Converters** (`converters.py`): Translate between the two layers

### The StockSelection Class (Planning Entity)

```python
@planning_entity
@dataclass
class StockSelection:
    stock_id: Annotated[str, PlanningId]       # "AAPL", "GOOGL", etc.
    stock_name: str                             # "Apple Inc."
    sector: str                                 # "Technology"
    predicted_return: float                     # 0.12 = 12%
    selection: Annotated[SelectionValue | None, PlanningVariable] = None
```

**What it represents:** A stock that could be included in the portfolio.

**Key fields:**
- `stock_id`: Unique identifier (ticker symbol)
- `stock_name`: Human-readable company name
- `sector`: Industry classification for diversification
- `predicted_return`: ML model's expected return (decimal: 0.12 = 12%)
- **`selection`**: The decision — should this stock be in the portfolio?

**Important annotations:**
- `@planning_entity`: Tells SolverForge this class contains decisions to make
- `PlanningVariable`: Marks `selection` as the decision variable

**Optimization concept:** This is a **planning variable** — the value the solver assigns. Each stock starts with `selection=None` (undecided). The solver tries SELECTED vs NOT_SELECTED for each stock, evaluating according to your constraints.

### The SelectionValue Pattern

Unlike employee scheduling where the planning variable is a reference to another entity, portfolio optimization uses a **Boolean selection pattern**:

```python
@dataclass
class SelectionValue:
    """Wrapper for True/False selection state."""
    value: bool

SELECTED = SelectionValue(True)
NOT_SELECTED = SelectionValue(False)
```

**Why a wrapper?** SolverForge needs reference types for value ranges. We wrap the boolean in a dataclass so the solver can work with it.

**Convenience property:**
```python
@property
def selected(self) -> bool | None:
    """Check if stock is selected."""
    if self.selection is None:
        return None
    return self.selection.value
```

### The PortfolioConfig Class (Problem Fact)

```python
@dataclass
class PortfolioConfig:
    target_count: int = 20           # How many stocks to select
    max_per_sector: int = 5          # Max stocks in any sector
    unselected_penalty: int = 10000  # Soft penalty per unselected stock
```

**What it represents:** Configurable parameters that constraints read.

**Optimization concept:** This is a **problem fact** — immutable data that doesn't change during solving but influences constraint behavior. Making these configurable allows users to adjust the optimization without modifying constraint code.

### The PortfolioOptimizationPlan Class (Planning Solution)

```python
@planning_solution
@dataclass
class PortfolioOptimizationPlan:
    stocks: Annotated[list[StockSelection], PlanningEntityCollectionProperty, ValueRangeProvider]
    target_position_count: int = 20
    max_sector_percentage: float = 0.25
    portfolio_config: Annotated[PortfolioConfig, ProblemFactProperty]
    selection_range: Annotated[list[SelectionValue], ValueRangeProvider(id="selection_range")]
    score: Annotated[HardSoftScore | None, PlanningScore] = None
    solver_status: SolverStatus = SolverStatus.NOT_SOLVING
```

**What it represents:** The complete problem and its solution.

**Key fields:**
- `stocks`: All candidate stocks (planning entities)
- `portfolio_config`: Configuration parameters (problem fact)
- `selection_range`: [SELECTED, NOT_SELECTED] — possible values for each stock
- `score`: Solution quality metric (calculated by constraints)
- `solver_status`: Whether solving is active

**Annotations explained:**
- `@planning_solution`: Marks this as the top-level problem definition
- `PlanningEntityCollectionProperty`: The entities being optimized
- `ValueRangeProvider`: Tells solver what values can be assigned
- `ProblemFactProperty`: Immutable configuration data
- `PlanningScore`: Where the solver stores the calculated score

### Helper Methods for Business Metrics

The `PortfolioOptimizationPlan` class includes useful analytics:

```python
def get_selected_stocks(self) -> list[StockSelection]:
    """Return only stocks that are selected."""
    return [s for s in self.stocks if s.selected is True]

def get_expected_return(self) -> float:
    """Calculate total expected portfolio return."""
    weight = self.get_weight_per_stock()
    return sum(s.predicted_return * weight for s in self.get_selected_stocks())

def get_sector_weights(self) -> dict[str, float]:
    """Calculate weight per sector."""
    weight = self.get_weight_per_stock()
    sector_weights = {}
    for stock in self.get_selected_stocks():
        sector_weights[stock.sector] = sector_weights.get(stock.sector, 0) + weight
    return sector_weights
```

---

## How Optimization Works

Before diving into constraints, let's understand how the solver finds solutions.

### The Search Process (Simplified)

1. **Start with an initial solution** (often random selections)
2. **Evaluate the score** using your constraint functions
3. **Make a small change** (toggle one stock's selection)
4. **Evaluate the new score**
5. **Keep the change if it improves the score** (with some controlled randomness)
6. **Repeat millions of times** in seconds
7. **Return the best solution found**

### The Search Space

For a portfolio problem with 50 candidate stocks selecting exactly 20, there are **trillions of valid combinations**. The solver explores this space using smart heuristics, not brute force.

### The Score: How "Good" is a Portfolio?

Every solution gets a score with two parts:

```
0hard/-45000soft
```

- **Hard score**: Counts hard constraint violations (must be 0 for a valid portfolio)
- **Soft score**: Reflects optimization quality (higher/less negative is better)

**Scoring rules:**
- Hard score must be 0 or positive (negative = invalid portfolio)
- Among valid portfolios (hard score = 0), highest soft score wins
- Hard score always takes priority over soft score

**Portfolio example:**
```
-2hard/-35000soft  → Invalid: 2 constraint violations
0hard/-50000soft   → Valid but low quality
0hard/-25000soft   → Valid and better quality
```

---

## Writing Constraints: The Business Rules

Now the heart of the system. Open `src/portfolio_optimization/constraints.py`.

### The Constraint Provider Pattern

All constraints are registered in one function:

```python
@constraint_provider
def define_constraints(constraint_factory: ConstraintFactory) -> list[Constraint]:
    return [
        # Hard constraints
        must_select_target_count(constraint_factory),
        sector_exposure_limit(constraint_factory),
        # Soft constraints
        penalize_unselected_stock(constraint_factory),
        maximize_expected_return(constraint_factory),
    ]
```

Each constraint is a function returning a `Constraint` object. Let's examine them.

### Hard Constraint: Must Select Target Count

**Business rule:** "Don't select more than N stocks" (default 20)

```python
def must_select_target_count(constraint_factory: ConstraintFactory) -> Constraint:
    return (
        constraint_factory.for_each(StockSelection)
        .filter(lambda stock: stock.selected is True)
        .group_by(ConstraintCollectors.count())
        .join(PortfolioConfig)
        .filter(lambda count, config: count > config.target_count)
        .penalize(
            HardSoftScore.ONE_HARD,
            lambda count, config: count - config.target_count
        )
        .as_constraint("Must select target count")
    )
```

**How to read this:**
1. `for_each(StockSelection)`: Consider every stock
2. `.filter(...)`: Keep only selected stocks
3. `.group_by(count())`: Count how many are selected
4. `.join(PortfolioConfig)`: Access the configuration
5. `.filter(...)`: Keep only if count exceeds target
6. `.penalize(ONE_HARD, ...)`: Each extra stock adds 1 hard penalty

**Why only "not more than"?** We use a separate soft constraint to drive selection toward the target. This approach handles edge cases better than counting both over and under.

### Soft Constraint: Penalize Unselected Stock

**Business rule:** "Strongly prefer selecting stocks to meet the target"

```python
def penalize_unselected_stock(constraint_factory: ConstraintFactory) -> Constraint:
    return (
        constraint_factory.for_each(StockSelection)
        .filter(lambda stock: stock.selected is False)
        .join(PortfolioConfig)
        .penalize(
            HardSoftScore.ONE_SOFT,
            lambda stock, config: config.unselected_penalty  # Default 10000
        )
        .as_constraint("Penalize unselected stock")
    )
```

**How to read this:**
1. `for_each(StockSelection)`: Consider every stock
2. `.filter(...)`: Keep only unselected stocks
3. `.join(PortfolioConfig)`: Access the penalty value
4. `.penalize(ONE_SOFT, 10000)`: Each unselected stock costs 10000 soft points

**Why 10000?** This penalty is higher than the maximum return reward (~2000 per stock). This ensures the solver prioritizes reaching 20 stocks before optimizing returns.

**Example with 25 stocks:**
- Optimal: 20 selected + 5 unselected = -50000 soft penalty
- If returns reward is ~30000, final soft score is around -20000soft

### Hard Constraint: Sector Exposure Limit

**Business rule:** "No sector can exceed N stocks" (default 5 = 25% of 20)

```python
def sector_exposure_limit(constraint_factory: ConstraintFactory) -> Constraint:
    return (
        constraint_factory.for_each(StockSelection)
        .filter(lambda stock: stock.selected is True)
        .group_by(
            lambda stock: stock.sector,      # Group by sector name
            ConstraintCollectors.count()      # Count stocks per sector
        )
        .join(PortfolioConfig)
        .filter(lambda sector, count, config: count > config.max_per_sector)
        .penalize(
            HardSoftScore.ONE_HARD,
            lambda sector, count, config: count - config.max_per_sector
        )
        .as_constraint("Max stocks per sector")
    )
```

**How to read this:**
1. `for_each(StockSelection)`: All stocks
2. `.filter(...)`: Keep only selected stocks
3. `.group_by(sector, count())`: Count selected stocks in each sector
4. `.join(PortfolioConfig)`: Access the sector limit
5. `.filter(...)`: Keep sectors exceeding the limit
6. `.penalize(...)`: Penalty = stocks over limit per sector

**Finance concept:** This enforces **diversification**. If Tech crashes 50%, you only lose 25% × 50% = 12.5% of your portfolio, not 40% × 50% = 20%.

### Soft Constraint: Maximize Expected Return

**Business rule:** "Among valid portfolios, prefer stocks with higher predicted returns"

```python
def maximize_expected_return(constraint_factory: ConstraintFactory) -> Constraint:
    return (
        constraint_factory.for_each(StockSelection)
        .filter(lambda stock: stock.selected is True)
        .reward(
            HardSoftScore.ONE_SOFT,
            lambda stock: int(stock.predicted_return * 10000)
        )
        .as_constraint("Maximize expected return")
    )
```

**How to read this:**
1. `for_each(StockSelection)`: All stocks
2. `.filter(...)`: Keep only selected stocks
3. `.reward(...)`: Add points based on predicted return

**Why multiply by 10000?** Converts decimal returns (0.12) to integer scores (1200). A stock with 12% predicted return adds 1200 soft points.

**Example calculation:**
| Stock | Return | Score Contribution |
|-------|--------|-------------------|
| NVDA | 20% | +2000 |
| AAPL | 12% | +1200 |
| JPM | 8% | +800 |
| XOM | 4% | +400 |

---

## The Solver Engine

Now let's see how the solver is configured. Open `src/portfolio_optimization/solver.py`:

```python
def create_solver_config(termination_seconds: int = 30) -> SolverConfig:
    return SolverConfig(
        solution_class=PortfolioOptimizationPlan,
        entity_class_list=[StockSelection],
        score_director_factory_config=ScoreDirectorFactoryConfig(
            constraint_provider_function=define_constraints
        ),
        termination_config=TerminationConfig(
            spent_limit=Duration(seconds=termination_seconds)
        ),
    )

solver_config = create_solver_config()
solver_manager = SolverManager.create(SolverFactory.create(solver_config))
solution_manager = SolutionManager.create(solver_manager)
```

### Configuration Breakdown

**`solution_class`**: Your planning solution class (`PortfolioOptimizationPlan`)

**`entity_class_list`**: Planning entities to optimize (`[StockSelection]`)

**`score_director_factory_config`**: Contains the constraint provider function
- Note: Nested inside `ScoreDirectorFactoryConfig`, not directly in `SolverConfig`

**`termination_config`**: When to stop solving
- `spent_limit=Duration(seconds=30)`: Stop after 30 seconds

### SolverManager: Asynchronous Solving

`SolverManager` handles solving in the background without blocking your API:

```python
# Start solving (non-blocking)
solver_manager.solve_and_listen(job_id, portfolio, callback_function)

# Check status
status = solver_manager.get_solver_status(job_id)

# Get current best solution
solution = solver_manager.get_solution(job_id)

# Stop early
solver_manager.terminate_early(job_id)
```

### Solving Timeline

**Small problems** (25 stocks, select 20):
- Initial valid solution: < 1 second
- Good solution: 5-10 seconds
- Optimal or near-optimal: 30 seconds

**Large problems** (50+ stocks, select 20):
- Initial valid solution: 1-3 seconds
- Good solution: 15-30 seconds
- High-quality: 60-120 seconds

**Factors affecting speed:**
- Number of candidate stocks (search space size)
- Sector distribution (tighter constraints = harder)
- How many stocks to select vs available

---

## Web Interface and API

### REST API Endpoints

Open `src/portfolio_optimization/rest_api.py` to see the API:

#### GET /demo-data

Returns available demo datasets:

```json
["SMALL", "LARGE"]
```

#### GET /demo-data/{dataset_id}

Generates and returns sample stock data:

```json
{
  "stocks": [
    {
      "stockId": "AAPL",
      "stockName": "Apple Inc.",
      "sector": "Technology",
      "predictedReturn": 0.12,
      "selected": null
    }
  ],
  "targetPositionCount": 20,
  "maxSectorPercentage": 0.25
}
```

#### POST /portfolios

Submit a portfolio for optimization:

**Request body:** Same format as demo-data response

**Response:** Job ID as plain text
```
"a1b2c3d4-e5f6-7890-abcd-ef1234567890"
```

**Implementation highlights:**
```python
@app.post("/portfolios")
async def solve_portfolio(plan_model: PortfolioOptimizationPlanModel) -> str:
    job_id = str(uuid4())
    plan = model_to_plan(plan_model)
    data_sets[job_id] = plan

    # Support custom termination time
    termination_seconds = 30
    if plan_model.solver_config:
        termination_seconds = plan_model.solver_config.termination_seconds

    config = create_solver_config(termination_seconds)
    manager = SolverManager.create(SolverFactory.create(config))
    solver_managers[job_id] = manager

    manager.solve_and_listen(job_id, plan, lambda sol: update_portfolio(job_id, sol))
    return job_id
```

#### GET /portfolios/{problem_id}

Get current solution:

```json
{
  "stocks": [...],
  "targetPositionCount": 20,
  "maxSectorPercentage": 0.25,
  "score": "0hard/-25000soft",
  "solverStatus": "SOLVING_ACTIVE"
}
```

#### GET /portfolios/{problem_id}/status

Lightweight status check with metrics:

```json
{
  "score": {
    "hardScore": 0,
    "softScore": -25000
  },
  "solverStatus": "SOLVING_ACTIVE",
  "selectedCount": 20,
  "expectedReturn": 0.1125,
  "sectorWeights": {
    "Technology": 0.25,
    "Healthcare": 0.25,
    "Finance": 0.25,
    "Energy": 0.25
  }
}
```

#### DELETE /portfolios/{problem_id}

Stop solving early and return best solution found.

#### PUT /portfolios/analyze

Analyze a portfolio's constraint violations in detail:

```json
{
  "constraints": [
    {
      "name": "Max stocks per sector",
      "weight": "1hard",
      "score": "-1hard",
      "matches": [
        {
          "name": "Max stocks per sector",
          "score": "-1hard",
          "justification": "Technology: 6 stocks (limit 5)"
        }
      ]
    }
  ]
}
```

### Web UI Flow

The `static/app.js` implements this polling workflow:

1. **User opens page** → Load demo data (`GET /demo-data/SMALL`)
2. **Display** stocks grouped by sector with predicted returns
3. **User clicks "Solve"** → `POST /portfolios` (get job ID back)
4. **Poll** `GET /portfolios/{id}/status` every 500ms
5. **Update UI** with latest selections and score in real-time
6. **When** `solverStatus === "NOT_SOLVING"` → Stop polling
7. **Display** final score, selected stocks, and sector allocation chart

---

## Making Your First Customization

The quickstart includes a tutorial constraint that demonstrates a common pattern. Let's understand how it works and then learn how to create similar constraints.

### Understanding the Preferred Sector Bonus

The codebase includes `preferred_sector_bonus` which gives a small bonus to Technology and Healthcare stocks. This constraint is **disabled by default** (commented out in `define_constraints()`) but serves as a useful example.

**Business rule:** "Slightly favor Technology and Healthcare stocks (higher growth sectors)"

### The Constraint Implementation

Find this in `src/portfolio_optimization/constraints.py` around line 200:

```python
# TUTORIAL: Uncomment this constraint to add sector preference
# def preferred_sector_bonus(constraint_factory: ConstraintFactory):
#     """Soft constraint: Give a small bonus to stocks from preferred sectors."""
#     PREFERRED_SECTORS = {"Technology", "Healthcare"}
#     BONUS_POINTS = 50  # Small bonus per preferred stock
#
#     return (
#         constraint_factory.for_each(StockSelection)
#         .filter(lambda stock: stock.selected is True)
#         .filter(lambda stock: stock.sector in PREFERRED_SECTORS)
#         .reward(
#             HardSoftScore.ONE_SOFT,
#             lambda stock: BONUS_POINTS
#         )
#         .as_constraint("Preferred sector bonus")
#     )
```

**How this works:**
1. Find all selected stocks
2. Keep only those in preferred sectors
3. Reward each with 50 bonus points

### Enabling the Constraint

1. **Uncomment the function** (remove the `#` comment markers)

2. **Register it** in `define_constraints()`:
   ```python
   return [
       must_select_target_count(constraint_factory),
       sector_exposure_limit(constraint_factory),
       penalize_unselected_stock(constraint_factory),
       maximize_expected_return(constraint_factory),
       preferred_sector_bonus(constraint_factory),  # ADD THIS LINE
   ]
   ```

3. **Restart the server** and solve again

4. **Observe** the portfolio now slightly favors Tech and Healthcare stocks

### Why 50 Points?

The bonus is intentionally small (50) compared to return rewards (1000-2000 per stock). This makes it a **tiebreaker** rather than an override:

- If two stocks have similar predicted returns, prefer the one in a preferred sector
- Don't sacrifice significant returns just to pick a preferred sector

### Adding a Test

Add a test class to `tests/test_constraints.py`:

```python
from portfolio_optimization.constraints import preferred_sector_bonus

class TestPreferredSectorBonus:
    def test_technology_stock_rewarded(self) -> None:
        """Technology stocks should receive bonus."""
        stock = create_stock("TECH1", sector="Technology", selected=True)

        constraint_verifier.verify_that(preferred_sector_bonus).given(
            stock
        ).rewards_with(50)

    def test_energy_stock_not_rewarded(self) -> None:
        """Energy stocks should not receive bonus."""
        stock = create_stock("ENGY1", sector="Energy", selected=True)

        constraint_verifier.verify_that(preferred_sector_bonus).given(
            stock
        ).rewards(0)

    def test_unselected_tech_not_rewarded(self) -> None:
        """Unselected stocks don't receive bonus even if in preferred sector."""
        stock = create_stock("TECH1", sector="Technology", selected=False)

        constraint_verifier.verify_that(preferred_sector_bonus).given(
            stock
        ).rewards(0)
```

Run with:
```bash
pytest tests/test_constraints.py::TestPreferredSectorBonus -v
```

---

## Advanced Constraint Patterns

### Pattern 1: Volatility Risk Penalty

**Scenario:** Penalize portfolios with high variance in predicted returns (higher risk).

```python
def penalize_high_volatility(constraint_factory: ConstraintFactory) -> Constraint:
    """
    Soft constraint: Penalize portfolios with high return variance.

    Risk-averse investors prefer consistent returns over volatile ones.
    """
    return (
        constraint_factory.for_each(StockSelection)
        .filter(lambda stock: stock.selected is True)
        .group_by(
            ConstraintCollectors.to_list(lambda stock: stock.predicted_return)
        )
        .filter(lambda returns: len(returns) >= 2)
        .penalize(
            HardSoftScore.ONE_SOFT,
            lambda returns: int(calculate_variance(returns) * 10000)
        )
        .as_constraint("High volatility penalty")
    )

def calculate_variance(returns: list[float]) -> float:
    mean = sum(returns) / len(returns)
    return sum((r - mean) ** 2 for r in returns) / len(returns)
```

### Pattern 2: Minimum Sector Representation

**Scenario:** Ensure each sector has at least 2 stocks (broader diversification).

```python
def minimum_sector_representation(constraint_factory: ConstraintFactory) -> Constraint:
    """
    Hard constraint: Each sector must have at least 2 stocks.

    Ensures broader diversification beyond just max limits.
    """
    MIN_PER_SECTOR = 2
    KNOWN_SECTORS = {"Technology", "Healthcare", "Finance", "Energy"}

    return (
        constraint_factory.for_each(StockSelection)
        .filter(lambda stock: stock.selected is True)
        .group_by(lambda stock: stock.sector, ConstraintCollectors.count())
        .filter(lambda sector, count: sector in KNOWN_SECTORS and count < MIN_PER_SECTOR)
        .penalize(
            HardSoftScore.ONE_HARD,
            lambda sector, count: MIN_PER_SECTOR - count
        )
        .as_constraint("Minimum sector representation")
    )
```

### Pattern 3: Exclude Specific Stocks

**Scenario:** Some stocks are on a "do not buy" list (regulatory, ethical, etc.).

```python
def exclude_blacklisted_stocks(constraint_factory: ConstraintFactory) -> Constraint:
    """
    Hard constraint: Never select blacklisted stocks.

    Useful for regulatory compliance or ethical investing.
    """
    BLACKLIST = {"TOBACCO1", "GAMBLING2", "WEAPONS3"}

    return (
        constraint_factory.for_each(StockSelection)
        .filter(lambda stock: stock.selected is True)
        .filter(lambda stock: stock.stock_id in BLACKLIST)
        .penalize(HardSoftScore.ONE_HARD)
        .as_constraint("Exclude blacklisted stocks")
    )
```

### Pattern 4: Sector Weight Balance

**Scenario:** Prefer portfolios where no sector is significantly larger than others.

```python
def balance_sector_weights(constraint_factory: ConstraintFactory) -> Constraint:
    """
    Soft constraint: Prefer balanced sector allocation.

    Uses load balancing to penalize uneven distribution.
    """
    return (
        constraint_factory.for_each(StockSelection)
        .filter(lambda stock: stock.selected is True)
        .group_by(lambda stock: stock.sector, ConstraintCollectors.count())
        .group_by(
            ConstraintCollectors.load_balance(
                lambda sector, count: sector,
                lambda sector, count: count
            )
        )
        .penalize(
            HardSoftScore.ONE_SOFT,
            lambda balance: int(balance.unfairness() * 100)
        )
        .as_constraint("Balance sector weights")
    )
```

---

## Testing and Validation

### Unit Testing Constraints

The quickstart uses `ConstraintVerifier` for isolated constraint testing. See `tests/test_constraints.py`:

```python
from solverforge_legacy.solver.test import ConstraintVerifier

constraint_verifier = ConstraintVerifier.build(
    define_constraints, PortfolioOptimizationPlan, StockSelection
)

DEFAULT_CONFIG = PortfolioConfig(target_count=20, max_per_sector=5, unselected_penalty=10000)

def create_stock(stock_id, sector="Technology", predicted_return=0.10, selected=True):
    selection_value = SELECTED if selected else NOT_SELECTED
    return StockSelection(
        stock_id=stock_id,
        stock_name=f"{stock_id} Corp",
        sector=sector,
        predicted_return=predicted_return,
        selection=selection_value,
    )
```

**Test patterns:**

**Verify no penalty:**
```python
def test_at_limit_no_penalty(self):
    stocks = [create_stock(f"TECH{i}", sector="Technology") for i in range(5)]
    constraint_verifier.verify_that(sector_exposure_limit).given(
        *stocks, DEFAULT_CONFIG
    ).penalizes(0)
```

**Verify exact penalty amount:**
```python
def test_one_over_limit_penalizes_1(self):
    stocks = [create_stock(f"TECH{i}", sector="Technology") for i in range(6)]
    constraint_verifier.verify_that(sector_exposure_limit).given(
        *stocks, DEFAULT_CONFIG
    ).penalizes_by(1)
```

**Verify reward amount:**
```python
def test_high_return_stock_rewarded(self):
    stock = create_stock("AAPL", predicted_return=0.12, selected=True)
    constraint_verifier.verify_that(maximize_expected_return).given(
        stock
    ).rewards_with(1200)  # 0.12 * 10000
```

### Running Tests

```bash
# All tests
pytest

# Verbose output
pytest -v

# Specific test file
pytest tests/test_constraints.py

# Specific test class
pytest tests/test_constraints.py::TestSectorExposureLimit

# With coverage
pytest --cov=portfolio_optimization
```

### Integration Testing: Full Solve

Test the complete solving cycle in `tests/test_feasible.py`:

```python
def test_small_dataset_feasible():
    """Solver should find a feasible solution for small dataset."""
    plan = generate_demo_data(DemoData.SMALL)

    # All stocks start unselected
    assert all(s.selection is None for s in plan.stocks)

    # Solve for 10 seconds
    solution = solve_for_seconds(plan, 10)

    # Should select exactly 20 stocks
    assert solution.get_selected_count() == 20

    # Should have no sector over 25%
    for sector, weight in solution.get_sector_weights().items():
        assert weight <= 0.26, f"{sector} at {weight*100}%"

    # Should have 0 hard score (feasible)
    assert solution.score.hard_score == 0
```

---

## Quick Reference

### File Locations

| Need to... | Edit this file |
|------------|----------------|
| Add/change business rule | `src/portfolio_optimization/constraints.py` |
| Add field to StockSelection | `src/portfolio_optimization/domain.py` + `converters.py` |
| Change default config | `src/portfolio_optimization/domain.py` (PortfolioConfig) |
| Change solve time | `src/portfolio_optimization/solver.py` or API parameter |
| Add REST endpoint | `src/portfolio_optimization/rest_api.py` |
| Change demo data | `src/portfolio_optimization/demo_data.py` |
| Change UI | `static/index.html`, `static/app.js` |

### Common Constraint Patterns

**Count selected stocks:**
```python
constraint_factory.for_each(StockSelection)
    .filter(lambda stock: stock.selected is True)
    .group_by(ConstraintCollectors.count())
    .filter(lambda count: count > MAX)
    .penalize(...)
```

**Group by sector and count:**
```python
constraint_factory.for_each(StockSelection)
    .filter(lambda stock: stock.selected is True)
    .group_by(lambda stock: stock.sector, ConstraintCollectors.count())
    .filter(lambda sector, count: count > MAX)
    .penalize(...)
```

**Reward based on attribute:**
```python
constraint_factory.for_each(StockSelection)
    .filter(lambda stock: stock.selected is True)
    .reward(HardSoftScore.ONE_SOFT, lambda stock: int(stock.attribute * 10000))
```

**Filter by set membership:**
```python
constraint_factory.for_each(StockSelection)
    .filter(lambda stock: stock.selected is True)
    .filter(lambda stock: stock.sector in PREFERRED_SECTORS)
    .reward(...)
```

**Access configurable parameters:**
```python
constraint_factory.for_each(StockSelection)
    .filter(...)
    .join(PortfolioConfig)
    .filter(lambda stock, config: some_condition(stock, config))
    .penalize(HardSoftScore.ONE_HARD, lambda stock, config: penalty(config))
```

### Common Gotchas

1. **Forgot to register constraint** in `define_constraints()` return list
   - Symptom: Constraint not enforced

2. **Using wrong score type**
   - `HardSoftScore.ONE_HARD` for must-satisfy rules
   - `HardSoftScore.ONE_SOFT` for preferences

3. **Boolean vs SelectionValue confusion**
   - Use `stock.selected is True` (the property)
   - Not `stock.selection == True` (would compare wrong type)

4. **Empty stream returns nothing, not 0**
   - If no stocks are selected, `group_by(count())` produces nothing
   - Can't use "must have at least N" pattern naively

5. **Score sign confusion**
   - Higher soft score is better (less negative)
   - Use `.reward()` to add points, `.penalize()` to subtract

6. **Forgetting to pass config to constraint tests**
   - Parameterized constraints need `PortfolioConfig` as a problem fact
   - `constraint_verifier.verify_that(...).given(*stocks, DEFAULT_CONFIG)`

### Debugging Tips

**Enable verbose logging:**
```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

**Use the /analyze endpoint:**
```bash
curl -X PUT http://localhost:8080/portfolios/analyze \
  -H "Content-Type: application/json" \
  -d @my_portfolio.json
```

**Print in constraints (temporary debugging):**
```python
.filter(lambda stock: (
    print(f"Checking {stock.stock_id}: {stock.sector}") or
    stock.sector in PREFERRED_SECTORS
))
```

---

## Additional Resources

- [GitHub Repository](https://github.com/SolverForge/solverforge-quickstarts)
- [Employee Scheduling Quickstart](/docs/getting-started/employee-scheduling) — Different problem domain, same patterns
- [Constraint Optimization Primer](https://en.wikipedia.org/wiki/Constraint_satisfaction_problem)
