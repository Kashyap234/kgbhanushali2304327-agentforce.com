public class BotConfidenceChecker {

    // This is the output variable the bot will receive
    public class ConfidenceResult {
        @InvocableVariable(label='Confidence Status' description='Returns High or Low confidence')
        public String status;
    }

    // This is the method the bot will call
    @InvocableMethod(label='Check Bot Intent Confidence' description='Checks if confidence is above a threshold')
    public static List<ConfidenceResult> checkConfidence(List<Decimal> confidenceScores) {

        // Define your threshold
        Decimal threshold = 0.50;

        // Get the score from the bot (it's always the first in the list)
        Decimal currentConfidence = confidenceScores[0];
        
        // Prepare the result object
        ConfidenceResult result = new ConfidenceResult();

        // Check the confidence and set the output status
        if (currentConfidence < threshold) {
            result.status = 'LowConfidence';
        } else {
            result.status = 'HighConfidence';
        }

        // Return the result back to the bot
        return new List<ConfidenceResult>{ result };
    }
}