package com.example.ant.ant;
import android.content.Context;
import android.os.ConditionVariable;
import android.util.Pair;

import java.io.Closeable;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.Future;
import org.tensorflow.lite.examples.transfer.api.AssetModelLoader;
import org.tensorflow.lite.examples.transfer.api.TransferLearningModel;
import org.tensorflow.lite.examples.transfer.api.TransferLearningModel.LossConsumer;
import org.tensorflow.lite.examples.transfer.api.TransferLearningModel.Prediction;

/**
 * App-layer wrapper for {@link TransferLearningModel}.
 *
 * <p>This wrapper allows to run training continuously, using start/stop API, in contrast to
 * run-once API of {@link TransferLearningModel}.
 */
public class TransferLearningModelWrapper implements Closeable {

    /**
     * CIFAR10 image size. This cannot be changed as the TFLite model's input layer expects
     * a 32x32x3 input.
     */

    private final TransferLearningModel model;

    private final ConditionVariable shouldTrain = new ConditionVariable();
    private volatile LossConsumer lossConsumer;
    private Context context;
    TransferLearningModelWrapper(Context context) {
        model =
                new TransferLearningModel(
                        new AssetModelLoader(context, "model"),
                        Arrays.asList("cat", "dog", "truck", "bird",
                                "airplane", "ship", "frog", "horse", "deer",
                                "automobile"));
        this.context = context;
    }


    public void train(int epochs){
        new Thread(() -> {
            shouldTrain.block();
            try {
                model.train(epochs, lossConsumer).get();
            } catch (ExecutionException e) {
                throw new RuntimeException("Exception occurred during model training", e.getCause());
            } catch (InterruptedException e) {
                // no-op
            }
        }).start();
    }

    // This method is thread-safe.
    public Future<Void> addSample(float[] image, String className, Boolean isTraining) {
        return model.addSample(image, className, isTraining);
    }

    public Pair<Float, Float> calculateTestStatistics(){
        return model.getTestStatistics();
    }

    // This method is thread-safe, but blocking.
    public List<Map<String,Object>> predict(float[] image) {
       Prediction[] predictions = model.predict(image);
        List<Map<String, Object>> predictionMaps = new ArrayList<>();
        for (Prediction prediction : Objects.requireNonNull(predictions)) {
            Map<String, Object> predictionMap = new HashMap<>();
            predictionMap.put("className", prediction.getClassName());
            predictionMap.put("confidence", prediction.getConfidence());
            predictionMaps.add(predictionMap);
        }
        return predictionMaps;
    }

    public int getTrainBatchSize() {
        return model.getTrainBatchSize();
    }

    /**
     * Start training the model continuously until {@link #disableTraining() disableTraining} is
     * called.
     *
     * @param lossConsumer callback that the loss values will be passed to.
     */
    public void enableTraining(LossConsumer lossConsumer) {
        this.lossConsumer = lossConsumer;
        shouldTrain.open();
    }


    public int getSize_Training() {
        return model.getSize_Training();
    }

    public int getSize_Testing() { return model.getSize_Testing(); }

    public ByteBuffer[] getParameters()  {
        return model.getParameters();
    }

    public void updateParameters(ByteBuffer[] newParams) {
        model.updateParameters(newParams);
    }

    public void disableTraining() {
        shouldTrain.close();
    }

    public void close() {
        model.close();
    }
}