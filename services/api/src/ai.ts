export type InsightClassification =
  | "fact"
  | "calculation"
  | "prediction"
  | "recommendation";

export interface InsightEvidence {
  sourceType: string;
  sourceId?: string;
  metric?: string;
  value?: string | number;
  window?: string;
}

export interface BusinessInsight {
  id: string;
  type: string;
  classification: InsightClassification;
  title: string;
  message: string;
  evidence: readonly InsightEvidence[];
  generatedBy: "deterministic" | "external_ai";
  generatedAt: string;
  expiresAt?: string;
}

export interface AiExplanationRequest {
  question: string;
  facts: Readonly<Record<string, string | number | boolean | null>>;
  evidence: readonly InsightEvidence[];
}

export interface AiExplanationResult {
  text: string;
  provider: string;
  model?: string;
}

export interface AiExplanationAdapter {
  readonly provider: string;
  isAvailable(): Promise<boolean>;
  explain(request: AiExplanationRequest): Promise<AiExplanationResult>;
}

export class UnconfiguredAiExplanationAdapter
  implements AiExplanationAdapter {
  readonly provider = "unconfigured";

  async isAvailable(): Promise<boolean> {
    return false;
  }

  async explain(
    _request: AiExplanationRequest
  ): Promise<AiExplanationResult> {
    throw new Error("External AI is not configured");
  }
}

export function validateInsight(insight: BusinessInsight): void {
  if (!insight.title.trim() || !insight.message.trim()) {
    throw new Error("Insight title and message are required");
  }
  if (insight.evidence.length === 0) {
    throw new Error("Every insight requires inspectable evidence");
  }
  if (
    insight.generatedBy === "external_ai" &&
    insight.classification === "fact" &&
    insight.evidence.every((item) => item.value === undefined)
  ) {
    throw new Error("AI-labelled fact requires concrete recorded evidence");
  }
}

export function purchaseSuggestion(input: {
  onHandMilli: number;
  averageDailySoldMilli: number;
  targetCoverageDays: number;
}): { suggestedOrderMilli: number; daysOfCover: number | null } {
  if (
    !Number.isSafeInteger(input.onHandMilli) ||
    !Number.isSafeInteger(input.averageDailySoldMilli) ||
    !Number.isSafeInteger(input.targetCoverageDays) ||
    input.averageDailySoldMilli < 0 ||
    input.targetCoverageDays <= 0
  ) {
    throw new Error("Invalid purchase suggestion input");
  }

  if (input.averageDailySoldMilli === 0) {
    return { suggestedOrderMilli: 0, daysOfCover: null };
  }

  const targetMilli =
    input.averageDailySoldMilli * input.targetCoverageDays;
  const suggestedOrderMilli = Math.max(0, targetMilli - input.onHandMilli);
  const daysOfCover = input.onHandMilli <= 0
    ? 0
    : Math.floor(input.onHandMilli / input.averageDailySoldMilli);

  return { suggestedOrderMilli, daysOfCover };
}

export function classifySalesChange(input: {
  currentMinor: number;
  comparisonMinor: number;
  materialityBps?: number;
}): "higher" | "lower" | "similar" | "no_comparison" {
  const materialityBps = input.materialityBps ?? 500;
  if (input.comparisonMinor <= 0) return "no_comparison";
  const deltaBps =
    ((input.currentMinor - input.comparisonMinor) * 10000) /
    input.comparisonMinor;
  if (deltaBps >= materialityBps) return "higher";
  if (deltaBps <= -materialityBps) return "lower";
  return "similar";
}
