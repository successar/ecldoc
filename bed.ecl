IMPORT ML;
IMPORT ML.Mat AS Mat;
IMPORT ML.Types AS Types;
IMPORT PBblas;
IMPORT ML.SVM;
IMPORT ML.Utils AS Utils;
IMPORT ML.DMAT as DMAT;
Layout_Cell := PBblas.Types.Layout_Cell;

/*
    The object of the classify module is to generate a classifier.
    A classifier is an 'equation' or 'algorithm' that allows the 'class' of an object to be imputed based upon other properties
    of an object.
*/

EXPORT Classify := MODULE

SHARED l_result := Types.l_result;

SHARED l_model := RECORD
  Types.t_RecordId    id := 0;      
  Types.t_FieldNumber number;       
  Types.t_Discrete    class_number; 
  REAL8 w;
END;

/*



*/
EXPORT Compare(DATASET(Types.DiscreteField) Dep,DATASET(l_result) Computed) := MODULE
  DiffRec := RECORD
    Types.t_FieldNumber classifier;  
    Types.t_Discrete  c_actual;      
    Types.t_Discrete  c_modeled;     
    Types.t_FieldReal score;         
  END;
  DiffRec  notediff(Computed le,Dep ri) := TRANSFORM
    SELF.c_actual := ri.value;
    SELF.c_modeled := le.value;
    SELF.score := le.conf;
    SELF.classifier := ri.number;
  END;
  SHARED J := JOIN(Computed,Dep,LEFT.id=RIGHT.id AND LEFT.number=RIGHT.number,notediff(LEFT,RIGHT));
  
  SHARED ConfMatrix_Rec := RECORD
    Types.t_FieldNumber classifier; 
    Types.t_Discrete c_actual;      
    Types.t_Discrete c_modeled;     
    Types.t_FieldNumber Cnt:=0;     
  END;
  SHARED class_cnt := TABLE(Dep,{classifier:= number, c_actual:= value, Cnt:= COUNT(GROUP)},number, value, FEW); 
  ConfMatrix_Rec form_cfmx(class_cnt le, class_cnt ri) := TRANSFORM
    SELF.classifier := le.classifier;
    SELF.c_actual:= le.c_actual;
    SELF.c_modeled:= ri.c_actual;
  END;
  SHARED cfmx := JOIN(class_cnt, class_cnt, LEFT.classifier = RIGHT.classifier, form_cfmx(LEFT, RIGHT)); 
  SHARED cross_raw := TABLE(J,{classifier,c_actual,c_modeled,Cnt := COUNT(GROUP)},classifier,c_actual,c_modeled,FEW); 
  ConfMatrix_Rec form_confmatrix(ConfMatrix_Rec le, cross_raw ri) := TRANSFORM
    SELF.Cnt  := ri.Cnt;
    SELF      := le;
  END;


  EXPORT CrossAssignments := JOIN(cfmx, cross_raw,
                              LEFT.classifier = RIGHT.classifier AND LEFT.c_actual = RIGHT.c_actual AND LEFT.c_modeled = RIGHT.c_modeled,
                              form_confmatrix(LEFT,RIGHT), LEFT OUTER, LOOKUP);


  EXPORT RecallByClass := SORT(TABLE(CrossAssignments, {classifier, c_actual, tp_rate := SUM(GROUP,IF(c_actual=c_modeled,cnt,0))/SUM(GROUP,cnt)}, classifier, c_actual, FEW), classifier, c_actual);

  EXPORT PrecisionByClass := SORT(TABLE(CrossAssignments,{classifier,c_modeled, Precision := SUM(GROUP,IF(c_actual=c_modeled,cnt,0))/SUM(GROUP,cnt)},classifier,c_modeled,FEW), classifier, c_modeled);


  FalseRate_rec := RECORD
    Types.t_FieldNumber classifier; 
    Types.t_Discrete c_modeled;     
    Types.t_FieldReal fp_rate;      
  END;
  wrong_modeled:= TABLE(CrossAssignments(c_modeled<>c_actual), {classifier, c_modeled, wcnt:= SUM(GROUP, cnt)}, classifier, c_modeled);
  j2:= JOIN(wrong_modeled, class_cnt, LEFT.classifier=RIGHT.classifier AND LEFT.c_modeled<>RIGHT.c_actual);
  allfalse:= TABLE(j2, {classifier, c_modeled, not_actual:= SUM(GROUP, cnt)}, classifier, c_modeled);
  EXPORT FP_Rate_ByClass := JOIN(wrong_modeled, allfalse, LEFT.classifier=RIGHT.classifier AND LEFT.c_modeled=RIGHT.c_modeled,
                          TRANSFOR(FalseRate_rec, SELF.fp_rate:= LEFT.wcnt/RIGHT.not_actual, SELF:= LEFT));

  EXPORT Accuracy := TABLE(CrossAssignments, {classifier, Accuracy:= SUM(GROUP,IF(c_actual=c_modeled,cnt,0))/SUM(GROUP, cnt)}, classifier);
END;
/*
  The purpose of this module is to provide a default interface to provide access to any of the 
  classifiers
*/
  EXPORT Default := MODULE,VIRTUAL
    EXPORT Base := Utils.Base; 
    
    SHARED CombineModels(DATASET(Types.NumericField) sofar,DATASET(Types.NumericField) new) := FUNCTION
      UBaseHigh := MAX(sofar(id<Base),id);
      High := IF(EXISTS(sofar),MAX(sofar,id),Base);
      UB := PROJECT(new(id<Base),TRANSFORM(Types.NumericField,SELF.id := LEFT.id+UBaseHigh,SELF := LEFT));
      UO := PROJECT(new(id>=Base),TRANSFORM(Types.NumericField,SELF.id := LEFT.id+High-Base,SELF := LEFT));
      RETURN sofar+UB+UO;
    END;
    
    EXPORT LearnC(DATASET(Types.NumericField) Indep,DATASET(Types.DiscreteField) Dep) := DATASET([],Types.NumericField); 
    
    EXPORT LearnD(DATASET(Types.DiscreteField) Indep,DATASET(Types.DiscreteField) Dep) := LearnC(PROJECT(Indep,Types.NumericField),Dep);
    
    EXPORT ClassifyC(DATASET(Types.NumericField) Indep,DATASET(Types.NumericField) mod) := DATASET([],l_result);
    
    EXPORT ClassifyD(DATASET(Types.DiscreteField) Indep,DATASET(Types.NumericField) mod) := ClassifyC(PROJECT(Indep,Types.NumericField),mod);
    EXPORT TestD(DATASET(Types.DiscreteField) Indep,DATASET(Types.DiscreteField) Dep) := FUNCTION
      a := LearnD(Indep,Dep);
      res := ClassifyD(Indep,a);
      RETURN Compare(Dep,res);
    END;
    EXPORT TestC(DATASET(Types.NumericField) Indep,DATASET(Types.DiscreteField) Dep) := FUNCTION
      a := LearnC(Indep,Dep);
      res := ClassifyC(Indep,a);
      RETURN Compare(Dep,res);
    END;
    EXPORT LearnDConcat(DATASET(Types.DiscreteField) Indep,DATASET(Types.DiscreteField) Dep, LearnD fnc) := FUNCTION
      
      
      dn := DEDUP(Dep,number,ALL);
      Types.NumericField loopBody(DATASET(Types.NumericField) sf,UNSIGNED c) := FUNCTION
        RETURN CombineModels(sf,fnc(Indep,Dep(number=dn[c].number)));
      END;
      RETURN LOOP(DATASET([],Types.NumericField),COUNT(dn),loopBody(ROWS(LEFT),COUNTER));
    END;
    EXPORT LearnCConcat(DATASET(Types.NumericField) Indep,DATASET(Types.DiscreteField) Dep, LearnC fnc) := FUNCTION
      
      
      dn := DEDUP(Dep,number,ALL);
      Types.NumericField loopBody(DATASET(Types.NumericField) sf,UNSIGNED c) := FUNCTION
        RETURN CombineModels(sf,fnc(Indep,Dep(number=dn[c].number)));
      END;
      RETURN LOOP(DATASET([],Types.NumericField),COUNT(dn),loopBody(ROWS(LEFT),COUNTER));
    END;
  END;

/*
  From Wikipedia: Naive Bayes classifier. https:
  "In machine learning, naive Bayes classifiers are a family of simple probabilistic classifiers based on applying Bayes' theorem with strong (naive) independence assumptions between the features...
  Naive Bayes classifiers are highly scalable, requiring a number of parameters linear in the number of variables (features/predictors) in a learning problem.
  Maximum-likelihood training can be done by evaluating a closed-form expression,[1]:718 which takes linear time, rather than by expensive iterative approximation as used for many other types of classifiers...
  Naive Bayes is a simple technique for constructing classifiers: models that assign class labels to problem instances, represented as vectors of feature values, where the class labels are drawn from some finite set.
  It is not a single algorithm for training such classifiers, but a family of algorithms based on a common principle: 
  All naive Bayes classifiers assume that the value of a particular feature is independent of the value of any other feature, given the class variable..."
*/
  EXPORT NaiveBayes(BOOLEAN IgnoreMissing = FALSE) := MODULE(DEFAULT)
/*  IMPORTANT NOTES:
    NaiveBayes assumes that the data is complete, that is, all instances must have a value for each attribute in the dataset.
    IgnoreMissing parameter:
    - TRUE: NaiveBayes will ignore features with a unique value when learning, resulting in smaller models; it also will ignore feature values of new instances that are not present in the model when classifying.
    - FALSE, default value: NaiveBayes will apply Laplace smoothing (https:
*/
    
    EXPORT LearnD(DATASET(Types.DiscreteField) Indep, DATASET(Types.DiscreteField) Dep) := FUNCTION
      RETURN ML.NaiveBayes.LearnD(Indep, Dep, IgnoreMissing,,);
    END;
    
    EXPORT Model(DATASET(Types.NumericField) mod) := FUNCTION
      RETURN ML.NaiveBayes.Model(mod);
    END;
    
    
    EXPORT ClassProbDistribD(DATASET(Types.DiscreteField) Indep, DATASET(Types.NumericField) mod) := FUNCTION
      RETURN ML.NaiveBayes.ClassProbDistribD(Indep, mod, IgnoreMissing,,);
    END;
    
    EXPORT ClassifyD(DATASET(Types.DiscreteField) Indep,DATASET(Types.NumericField) mod) := FUNCTION
      RETURN ML.NaiveBayes.ClassifyD(Indep, mod, IgnoreMissing,,);
    END;  
    /*From Wikipedia
    " ...When dealing with continuous data, a typical assumption is that the continuous values associated with each class are distributed according to a Gaussian distribution.
    For example, suppose the training data contain a continuous attribute, x. We first segment the data by the class, and then compute the mean and variance of x in each class.
    Let mu_c be the mean of the values in x associated with class c, and let sigma^2_c be the variance of the values in x associated with class c.
    Then, the probability density of some value given a class, P(x=v|c), can be computed by plugging v into the equation for a Normal distribution parameterized by mu_c and sigma^2_c..."
    */
    
    EXPORT LearnC(DATASET(Types.NumericField) Indep, DATASET(Types.DiscreteField) Dep) := FUNCTION
      RETURN ML.NaiveBayes.LearnC(Indep, Dep);
    END;
    
    EXPORT ModelC(DATASET(Types.NumericField) mod) := FUNCTION
      RETURN ML.NaiveBayes.ModelC(mod);
    END;
    
    
    EXPORT ClassProbDistribC(DATASET(Types.NumericField) Indep, DATASET(Types.NumericField) mod) := FUNCTION
      RETURN ML.NaiveBayes.ClassProbDistribC(Indep, mod);
    END;
    
    EXPORT ClassifyC(DATASET(Types.NumericField) Indep,DATASET(Types.NumericField) mod) := FUNCTION
      RETURN ML.NaiveBayes.ClassifyC(Indep, mod);
    END;
  END; 
  
  EXPORT SparseNaiveBayes(BOOLEAN IgnoreMissing = FALSE, Types.t_discrete defValue = 0) := MODULE(DEFAULT)
/*  IMPORTANT NOTES:
    This MODULE was created to deal with Sparse DATASETS where all "instance-attribute-value = defValue" were explicitly removed, as imported from Sparse ARFF files.
    Example for default value = 0:
    
                              | attr index starts in 0   | attr index starts in 1
    @data                     | @data                    | 
    0, 0, 1, 0, 0, posclass   | {2 1, 5 posclass}        | [{1, 3, 1}, {1, 6, 1},
    2, 0, 0, 0, 1, posclass   | {0 2, 4 1, 5 posclass}   |  {2, 1, 2}, {2, 5, 1}, {2, 6, 1},
    0, 0, 0, 0, 2, negclass   | {4 2, 5 negclass}        |  {3, 5, 2}, {3, 6, 0}]

    Highly sparse data can be represented with very few records, which saves disk space and accelerates calculations (based on pre computations on DefValue)
    SparseNaiveBayes assumes any independent missing equal to the defValue, for any other value the independent data must be complete. Dependent data must be complete.
    All independent records having value = defValue MUST be filtered out.
    There MUST be one additional record per instances having all their "value" fields = defValue: {id, number:= 0 and value:= 0} when calculating ClassProbDistribD or ClassifyD. 
    IgnoreMissing parameter:
    - TRUE: NaiveBayes will ignore features with a unique value when learning, resulting in smaller models; it also will ignore feature values of new instances that are not present in the model when classifying.
    - FALSE, default value: NaiveBayes will apply Laplace smoothing (https:
*/
    SHARED SparseData:= TRUE; 
    
    EXPORT LearnD(DATASET(Types.DiscreteField) Indep, DATASET(Types.DiscreteField) Dep) := FUNCTION
      RETURN ML.NaiveBayes.LearnD(Indep, Dep, IgnoreMissing, SparseData, defValue);
    END;
    
    EXPORT ModelD(DATASET(Types.NumericField) mod) := FUNCTION
      RETURN ML.NaiveBayes.Model(mod);
    END;
    
    EXPORT ClassProbDistribD(DATASET(Types.DiscreteField) Indep, DATASET(Types.NumericField) mod) := FUNCTION
      RETURN ML.NaiveBayes.ClassProbDistribD(Indep, mod, IgnoreMissing, SparseData, defValue);
    END;
    
    EXPORT ClassifyD(DATASET(Types.DiscreteField) Indep,DATASET(Types.NumericField) mod) := FUNCTION
      RETURN ML.NaiveBayes.ClassifyD(Indep, mod, IgnoreMissing, SparseData, defValue);
    END;  
  END; 

/*
  See: http:
  The inputs to the BuildPerceptron are:
  a) A dataset of discretized independant variables
  b) A dataset of class results (these must match in ID the discretized independant variables).
  c) Passes; number of passes over the data to make during the learning process
  d) Alpha is the learning rate - higher numbers may learn quicker - but may not converge
  Note the perceptron presently assumes the class values are ordinal eg 4>3>2>1>0

  Output: A table of weights for each independant variable for each class. 
  Those weights with number=class_number give the error rate on the last pass of the data
*/

  EXPORT Perceptron(UNSIGNED Passes,REAL8 Alpha = 0.1) := MODULE(DEFAULT)
    SHARED Thresh := 0.5; 

    EXPORT LearnD(DATASET(Types.DiscreteField) Indep,DATASET(Types.DiscreteField) Dep) := FUNCTION
      dd := Indep;
      cl := Dep;
      MaxFieldNumber := MAX(dd,number);
      FirstClassNo := MaxFieldNumber+1;
      clb := Utils.RebaseDiscrete(cl,FirstClassNo);
      LastClassNo := MAX(clb,number);
      all_fields := dd+clb;
  
  
      ready := SORT( DISTRIBUTE( all_fields, HASH(id) ), id, Number, LOCAL );
  
      WR := RECORD
        REAL8 W := 0;
        Types.t_FieldNumber number; 
        Types.t_Discrete class_number;
      END;
      VR := RECORD
        Types.t_FieldNumber number;
        Types.t_Discrete    value;
      END;
  
      InitWeights := FUNCTION
        Classes := TABLE(clb,{number},number,FEW);
        WR again(Classes le,UNSIGNED C) := TRANSFORM
          SELF.number := IF( C > MaxFieldNumber, le.number, C ); 
          SELF.class_number := le.number;
        END;
        RETURN NORMALIZE(Classes,MaxFieldNumber+2,again(LEFT,COUNTER-1));
      END;

      AccumRec := RECORD
        DATASET(WR) Weights;
        DATASET(VR) ThisRecord;
        Types.t_RecordId Processed;
      END;
  
      Learn(DATASET(WR) le,DATASET(VR) ri,Types.t_FieldNumber fn,Types.t_Discrete va) := FUNCTION
        let := le(class_number=fn);
        letn := let(number<>fn);     
        lep := le(class_number<>fn); 
    
        iv := RECORD
          REAL8 val;
        END;
    
        iv scor(le l,ri r) := TRANSFORM
          SELF.val := l.w*IF(r.number<>0,r.value,1);
        END;
        sc := JOIN(letn,ri,LEFT.number=RIGHT.number,scor(LEFT,RIGHT),LEFT OUTER);
        res := IF( SUM(sc,val) > Thresh, 1, 0 );
        err := va-res;
        let_e := PROJECT(let(number=fn),TRANSFORM(WR,SELF.w := LEFT.w+ABS(err), SELF:=LEFT)); 
        delta := alpha*err; 
    
        WR add(WR le,VR ri) := TRANSFORM
          SELF.w := le.w+delta*IF(ri.number=0,1,ri.value); 
          SELF := le;
        END;
        J := JOIN(letn,ri,LEFT.number=right.number,add(LEFT,RIGHT),LEFT OUTER);
        RETURN let_e+J+lep;
      END;
  
      WR Clean(DATASET(WR) w) := FUNCTION
        RETURN w(number<>class_number)+PROJECT(w(number=class_number),TRANSFORM(WR,SELF.w := 0, SELF := LEFT));
      END;
  
      WR Pass(DATASET(WR) we) := FUNCTION
    
    
        AccumRec TakeRecord(ready le,AccumRec ri) := TRANSFORM
          BOOLEAN lrn := le.number >= FirstClassNo;
          BOOLEAN init := ~EXISTS(ri.Weights);
          SELF.Weights := MAP ( init => Clean(we), 
                                ~lrn => ri.Weights,
                                Learn(ri.Weights,ri.ThisRecord,le.number,le.value) );
    
    
    
          SELF.ThisRecord := MAP ( ~lrn => ri.ThisRecord+ROW({le.number,le.value},VR),
                                  le.number = LastClassNo => DATASET([],VR),
                                  ri.ThisRecord);
          SELF.Processed := ri.Processed + IF( le.number = LastClassNo, 1, 0 );
        END;
      
      
      
        Blend(DATASET(WR) l,UNSIGNED lscale, DATASET(WR) r,UNSIGNED rscale) := FUNCTION
          lscaled := PROJECT(l(number<>class_number),TRANSFORM(WR,SELF.w := LEFT.w*lscale, SELF := LEFT));
          rscaled := PROJECT(r(number<>class_number),TRANSFORM(WR,SELF.w := LEFT.w*rscale, SELF := LEFT));
          unscaled := (l+r)(number=class_number);
          t := TABLE(lscaled+rscaled+unscaled,{number,class_number,w1 := SUM(GROUP,w)},number,class_number,FEW);
          RETURN PROJECT(t,TRANSFORM(WR,SELF.w := IF(LEFT.number=LEFT.class_number,LEFT.w1,LEFT.w1/(lscale+rscale)),SELF := LEFT));
        END;    
        AccumRec MergeP(AccumRec ri1,AccumRec ri2) := TRANSFORM
          SELF.ThisRecord := []; 
          SELF.Processed := ri1.Processed+ri2.Processed;
          SELF.Weights := ending(ri1.Weights,ri1.Processed,ri2.Weights,ri2.Processed);
        END;

        A := AGGREGATE(ready,AccumRec,TakeRecord(LEFT,RIGHT),MergeP(RIGHT1,RIGHT2))[1];
    
        RETURN A.Weights(class_number<>number)+PROJECT(A.Weights(class_number=number),TRANSFORM(WR,SELF.w := LEFT.w / A.Processed,SELF := LEFT));
      END;
      L := LOOP(InitWeights,Passes,PASS(ROWS(LEFT)));
      L1 := PROJECT(L,TRANSFORM(l_model,SELF.id := COUNTER+Base,SELF := LEFT));
      ML.ToField(L1,o);
      RETURN o;
    END;
    EXPORT Model(DATASET(Types.NumericField) mod) := FUNCTION
      ML.FromField(mod,l_model,o);
      RETURN o;
    END;
    EXPORT ClassifyD(DATASET(Types.DiscreteField) Indep,DATASET(Types.NumericField) mod) := FUNCTION
      mo := Model(mod);
      Ind := DISTRIBUTE(Indep,HASH(id));
      l_result note(Ind le,mo ri) := TRANSFORM
        SELF.conf := le.value*ri.w;
        SELF.number := ri.class_number;
        SELF.value := 0;
        SELF.id := le.id;
      END;
      
      j := JOIN(Ind,mo,LEFT.number=RIGHT.number,note(LEFT,RIGHT),MANY LOOKUP); 
      l_result ac(l_result le, l_result ri) := TRANSFORM
        SELF.conf := le.conf+ri.conf;
        SELF := le;
      END;
      
      t := ROLLUP(SORT(j,id,number,LOCAL),LEFT.id=RIGHT.id AND LEFT.number=RIGHT.number,ac(LEFT,RIGHT),LOCAL);
      
      l_result add_c(l_result le,mo ri) := TRANSFORM
        SELF.conf := le.conf+ri.w;
        SELF.value := IF(SELF.Conf>Thresh,1,0);
        SELF := le;
      END;
      t1 := JOIN(t,mo(number=0),LEFT.number=RIGHT.class_number,add_c(LEFT,RIGHT),LEFT OUTER);
      t2 := PROJECT(t1,TRANSFORM(l_Result,SELF.conf := ABS(LEFT.Conf-Thresh), SELF := LEFT));
      RETURN t2;
    END;
  END;
  /*
  Apply classification with Neural Network by using NeuralNetworks.ecl
  */
  EXPORT NeuralNetworksClassifier (DATASET(Types.DiscreteField) net, DATASET(Mat.Types.MUElement) IntW, DATASET(Mat.Types.MUElement) Intb, REAL8 LAMBDA=0.001, REAL8 ALPHA=0.1, UNSIGNED2 MaxIter=100, 
    UNSIGNED4 prows=0, UNSIGNED4 pcols=0, UNSIGNED4 Maxrows=0, UNSIGNED4 Maxcols=0) := MODULE(DEFAULT)
  SHARED NN := ML.NeuralNetworks(net, prows,  pcols, Maxrows,  Maxcols);
  EXPORT LearnC(DATASET(Types.NumericField) Indep, DATASET(Types.DiscreteField) Dep) := FUNCTION
    Y := PROJECT(Dep,Types.NumericField);
    groundTruth:= Utils.ToGroundTruth (Y);
    
    
    groundTruth_t := Mat.trans(groundTruth);
    groundTruth_NumericField := Types.FromMatrix (groundTruth_t);
    Learntmodel := NN.NNLearn(Indep, groundTruth_NumericField,IntW, Intb,  LAMBDA, ALPHA, MaxIter);
    RETURN Learntmodel;
  END;
  EXPORT Model(DATASET(Types.NumericField) Lmod) := FUNCTION
    RETURN NN.Model(Lmod);
  END;
  EXPORT ClassProbDistribC(DATASET(Types.NumericField) Indep,DATASET(Types.NumericField) mod) :=FUNCTION
    AEnd := NN.NNOutput(Indep,mod);
    RETURN AEnd;
  END;
  EXPORT ClassifyC(DATASET(Types.NumericField) Indep,DATASET(Types.NumericField) mod) := FUNCTION
    Classes := NN.NNClassify(Indep,mod);
    RETURN Classes;
  END;
  END;
  
  EXPORT Logistic_Model := MODULE(DEFAULT), VIRTUAL
    SHARED Logis_Model := RECORD(l_model)
      REAL8 SE;
    END;
    
    SHARED ZStat_Model := RECORD(Logis_Model)
      REAL8 z;
      REAL8 pVal;
    END;
    
    SHARED ConfInt_Model := RECORD(l_model)
      REAL8 lowerCI;
      REAL8 UpperCI;
    END;
    
    SHARED DevianceRec := RECORD
      Types.t_RecordID id;
      Types.t_FieldNumber classifier;  
      Types.t_Discrete  c_actual;      
      Types.t_FieldReal  c_modeled;    
      Types.t_FieldReal LL;         
      BOOLEAN isGreater;
    END;
    
    SHARED ResidDevRec := RECORD
      Types.t_FieldNumber classifier;
      REAL8 Deviance;
      UNSIGNED4 DF;
    END;
    
    EXPORT LearnCS(DATASET(Types.NumericField) Indep,DATASET(Types.DiscreteField) Dep) := DATASET([], Types.NumericField);
    EXPORT LearnC(DATASET(Types.NumericField) Indep,DATASET(Types.DiscreteField) Dep) := LearnCConcat(Indep,Dep,LearnCS);
    EXPORT Model(DATASET(Types.NumericField) mod) := FUNCTION
      ML.FromField(mod,Logis_Model,o);
      RETURN o;
    END;  
    
    SHARED norm_dist := ML.Distribution.Normal(0, 1);
    ZStat_Model zStat_Transform(Logis_Model mod) := TRANSFORM
      z := mod.w/mod.SE;
      SELF.z := z;
      SELF.pVal := 2 * (1 - norm_dist.Cumulative(ABS(z)));
      SELF := mod;
    END;
    EXPORT ZStat(DATASET(Types.NumericField) mod) := PROJECT(Model(mod), zStat_Transform(LEFT));
    
    confInt_Model confint_transform(Logis_Model b, REAL Margin) := TRANSFORM
      SELF.UpperCI := b.w + Margin * b.se;
      SELF.LowerCI := b.w - Margin * b.se;
      SELF := b;
    END;    
    EXPORT ConfInt(Types.t_fieldReal level, DATASET(Types.NumericField) mod) := FUNCTION
      newlevel := 100 - (100 - level)/2;
      Margin := norm_dist.NTile(newlevel);
      RETURN PROJECT(Model(mod),confint_transform(LEFT,Margin));
    END;
    
    EXPORT ClassifyS(DATASET(Types.NumericField) Indep,DATASET(Types.NumericField) mod) := DATASET([], Types.NumericField);   
    l_result tr(Types.NumericField le) := TRANSFORM
        SELF.value := IF ( le.value > 0.5,1,0);
        SELF.conf := ABS(le.value-0.5);
        SELF := le;
      END;
    EXPORT ClassifyC(DATASET(Types.NumericField) Indep,DATASET(Types.NumericField) mod) := PROJECT(ClassifyS(Indep, mod),tr(LEFT));
    
    DevianceRec  dev_t(Types.NumericField le, Types.DiscreteField ri) := TRANSFORM
      SELF.c_actual := ri.value;
      SELF.c_modeled := le.value;
      SELF.LL := -2 * (ri.value * LN(le.value) + (1 - ri.Value) * LN(1-le.Value));
      SELF.classifier := ri.number;
      SELF.id := ri.id;
      SELF.isGreater := IF(ri.value >= le.value, TRUE, FALSE);
    END;
    
    DevianceRec  dev_t2(REAL mu, Types.DiscreteField ri) := TRANSFORM
      SELF.c_actual := ri.value;
      SELF.c_modeled := mu;
      SELF.LL := -2 * (ri.value * LN(mu) + (1 - ri.Value) * LN(1-mu));
      SELF.classifier := ri.number;
      SELF.id := ri.id;
      SELF.isGreater := IF(ri.value >= mu, TRUE, FALSE);
    END;
    
    EXPORT DevianceC(DATASET(Types.NumericField) Indep,DATASET(Types.DiscreteField) Dep, DATASET(Types.NumericField) mod) := MODULE
      SHARED Dev := JOIN(ClassifyS(Indep, mod), Dep,LEFT.id = RIGHT.id AND LEFT.number = RIGHT.number,dev_t(LEFT,RIGHT));
      NullMu := TABLE(Dep, {number, Mu := AVE(GROUP, value)}, number, FEW, UNSORTED);
      SHARED NDev := JOIN(Dep, NullMu, LEFT.number = RIGHT.number, dev_t2(RIGHT.Mu, LEFT),LOOKUP); 
      EXPORT DevRes := PROJECT(Dev, TRANSFORM(DevianceRec, SELF.LL := SQRT(LEFT.LL) * IF(LEFT.isGreater, +1, -1); SELF := LEFT));
      EXPORT DevNull := PROJECT(NDev, TRANSFORM(DevianceRec, SELF.LL := SQRT(LEFT.LL) * IF(LEFT.isGreater, +1, -1); SELF := LEFT));
      SHARED p := MAX(Model(mod), number) + 1;
      EXPORT ResidDev := PROJECT(TABLE(Dev, {classifier, Deviance := SUM(GROUP, LL), DF := COUNT(GROUP) - p}, classifier, FEW, UNSORTED), ResidDevRec);
      EXPORT NullDev := PROJECT(TABLE(NDev, {classifier, Deviance := SUM(GROUP, LL), DF := COUNT(GROUP) - 1}, classifier, FEW, UNSORTED), ResidDevRec);
      EXPORT AIC := PROJECT(ResidDev, TRANSFORM({Types.t_FieldNumber classifier, REAL8 AIC}, 
                                                SELF.AIC := LEFT.Deviance + 2 * p; SELF := LEFT));
    END;
    
    EXPORT AOD(DATASET(ResidDevRec) R1, DATASET(ResidDevRec) R2) := FUNCTION
      AODRec := RECORD
        Types.t_FieldNumber classifier;
        UNSIGNED4 ResidDF;
        REAL8 ResidDeviance;
        UNSIGNED4 DF := 0.0;
        REAL8 Deviance := 0.0;
        REAL8 pValue := 0.0;
      END;
      c1 := PROJECT(R1, TRANSFORM(AODRec, SELF.ResidDF := LEFT.DF; SELF.ResidDeviance := LEFT.Deviance; SELF.classifier := LEFT.classifier));
      c2 := JOIN(R1, R2, LEFT.classifier = RIGHT.classifier, 
                      TRANSFORM(AODRec,     df := LEFT.DF - RIGHT.DF;
                                            dev := LEFT.Deviance - RIGHT.Deviance;
                                            dist := ML.Distribution.ChiSquare(df);
                                            SELF.ResidDF := RIGHT.DF; 
                                            SELF.ResidDeviance := RIGHT.Deviance; 
                                            SELF.classifier := RIGHT.classifier;
                                            SELF.DF := df; 
                                            SELF.Deviance := dev;
                                            SELF.pValue := ( 1 - dist.Cumulative(ABS(dev)))), LOOKUP);
      RETURN c1+c2;
    END;
      
  
    EXPORT DevianceD(DATASET(Types.DiscreteField) Indep, DATASET(Types.DiscreteField) Dep, DATASET(Types.NumericField) mod) :=
      DevianceC(PROJECT(Indep, Types.NumericField), Dep, mod);
  END;
/*
/*
  Logistic Regression implementation base on the iteratively-reweighted least squares (IRLS) algorithm:
  http:

  Logistic Regression module parameters:
  - Ridge: an optional ridge term used to ensure existance of Inv(X'*X) even if 
    some independent variables X are linearly dependent. In other words the Ridge parameter
    ensures that the matrix X'*X+mRidge is non-singular.
  - Epsilon: an optional parameter used to test convergence
  - MaxIter: an optional parameter that defines a maximum number of iterations

  The inputs to the Logis module are:
  a) A training dataset X of discretized independant variables
  b) A dataset of class results Y.

*/

  EXPORT Logistic_sparse(REAL8 Ridge=0.00001, REAL8 Epsilon=0.000000001, UNSIGNED2 MaxIter=200) := MODULE(Logistic_Model)
  
    Logis(DATASET(Types.NumericField) X,DATASET(Types.NumericField) Y) := MODULE
      SHARED mu_comp := ENUM ( Beta = 1,  Y = 2, VC = 3, Err = 4 );
      SHARED RebaseY := Utils.RebaseNumericField(Y);
      SHARED Y_Map := RebaseY.Mapping(1);
      Y_0 := RebaseY.ToNew(Y_Map);
      mY := Types.ToMatrix(Y_0);
      mX_0 := Types.ToMatrix(X);
      mX := IF(NOT EXISTS(mX_0), 
                    Mat.Vec.ToCol(Mat.Vec.From(Mat.Has(mY).Stats.xmax, 1.0), 1), 
                    Mat.InsertColumn(mX_0, 1, 1.0)); 

      mXstats := Mat.Has(mX).Stats;
      mX_n := mXstats.XMax;
      mX_m := mXstats.YMax;

      mW := Mat.Vec.ToCol(Mat.Vec.From(mX_n,1.0),1);
      mRidge := Mat.Vec.ToDiag(Mat.Vec.From(mX_m,ridge));
      mBeta0 := Mat.Vec.ToCol(Mat.Vec.From(mX_m,0.0),1);  
      mBeta00 := Mat.MU.To(mBeta0, mu_comp.Beta);
      OldExpY_0 := Mat.Vec.ToCol(Mat.Vec.From(mX_n,-1.0),1); 
      OldExpY_00 := Mat.MU.To(OldExpY_0, mu_comp.Y);
      mInv_xTWx0 := Mat.Identity(mX_m);
      mInv_xTWx00 := Mat.MU.To(mInv_xTWx0, mu_comp.VC);
      

      Step(DATASET(Mat.Types.MUElement) BetaPlusY) := FUNCTION
        OldExpY := Mat.MU.From(BetaPlusY, mu_comp.Y);
        AdjY := Mat.Mul(mX, Mat.MU.From(BetaPlusY, mu_comp.Beta));
        
        ExpY := Mat.Each.Each_Reciprocal(Mat.Each.Each_Add(Mat.Each.Each_Exp(Mat.Scale(AdjY, -1)),1));
        
        Deriv := Mat.Each.Each_Mul(expy,Mat.Each.Each_Add(Mat.Scale(ExpY, -1),1));
        
        W_AdjY := Mat.Each.Each_Mul(mW,Mat.Add(Mat.Each.Each_Mul(Deriv,AdjY),Mat.Sub(mY, ExpY)));
        
        Weights := Mat.Vec.ToDiag(Mat.Vec.FromCol(Mat.Each.Each_Mul(Deriv, mW),1));
        
        Inv_xTWx := Mat.Inv(Mat.Add(Mat.Mul(Mat.Mul(Mat.Trans(mX), weights), mX), mRidge));
        
        mBeta :=  Mat.Mul(Mat.Mul(Inv_xTWx, Mat.Trans(mX)), W_AdjY);
        err := SUM(Mat.Each.Each_Abs(Mat.Sub(ExpY, OldExpY)),value); 
        mErr := DATASET([{1,1,err}], Mat.Types.Element);
        RETURN Mat.MU.To(mBeta, mu_comp.Beta)+
              Mat.MU.To(ExpY, mu_comp.Y)+
              Mat.MU.To(Inv_xTWx, mu_comp.VC)+
              Mat.MU.To(mErr, mu_comp.Err);
      END;

      MaxErr := mX_n*Epsilon;
      IErr := Mat.MU.To(DATASET([{1,1,mX_n*Epsilon + 1}], Mat.Types.Element), mu_comp.Err);
      SHARED BetaPair := LOOP(mBeta00+OldExpY_00+mInv_xTWx00+IErr, (COUNTER <= MaxIter) 
                  AND (Mat.MU.From(ROWS(LEFT), mu_comp.Err)[1].value > MaxErr), Step(ROWS(LEFT)));  
      BetaM := Mat.MU.From(BetaPair, mu_comp.Beta);
      rebasedBetaNF := RebaseY.ToOld(Types.FromMatrix(BetaM), Y_Map);
      BetaNF := Types.FromMatrix(Mat.Trans(Types.ToMatrix(rebasedBetaNF)));
      
      EXPORT Beta := PROJECT(BetaNF,TRANSFORM(Types.NumericField,SELF.Number := LEFT.Number-1;SELF:=LEFT;));
      
      varCovar := Mat.MU.From(BetaPair, mu_comp.VC);
      SEM := Mat.Vec.ToCol(Mat.Vec.FromDiag(varCovar), 1);
      rebasedSENF := RebaseY.ToOld(Types.FromMatrix(SEM), Y_map);
      SENF := Types.FromMatrix(Mat.Trans(Types.ToMatrix(rebasedSENF)));
      EXPORT SE := PROJECT(SENF,TRANSFORM(Types.NumericField,SELF.Number := LEFT.Number-1;SELF:=LEFT;));
      
      Res0 := PROJECT(Beta, TRANSFORM(l_model, SELF.Id := COUNTER+Base,SELF.number := LEFT.number, 
          SELF.class_number := LEFT.id, SELF.w := LEFT.value));
      Res := JOIN(Res0, SE, LEFT.number = RIGHT.number AND LEFT.class_number = RIGHT.id, 
        TRANSFORM(Logis_Model,
          SELF.Id := LEFT.Id,SELF.number := LEFT.number, 
          SELF.class_number := LEFT.class_number, SELF.w := LEFT.w, SELF.se := SQRT(RIGHT.value)));
          
      ML.ToField(Res,o);
      EXPORT Mod := o;
      modelY_M := Mat.MU.From(BetaPair, mu_comp.Y);
      modelY_NF := Types.FromMatrix(modelY_M);
      EXPORT modelY := RebaseY.ToOld(modelY_NF, Y_Map);
    END;
    EXPORT LearnCS(DATASET(Types.NumericField) Indep,DATASET(Types.DiscreteField) Dep) := Logis(Indep,PROJECT(Dep,Types.NumericField)).mod;
    EXPORT LearnC(DATASET(Types.NumericField) Indep,DATASET(Types.DiscreteField) Dep) := LearnCConcat(Indep,Dep,LearnCS);
    EXPORT ClassifyS(DATASET(Types.NumericField) Indep,DATASET(Types.NumericField) mod) := FUNCTION
      mod0 := Model(mod);
      Beta0 := PROJECT(mod0,TRANSFORM(Types.NumericField,SELF.Number := LEFT.Number+1,SELF.id := LEFT.class_number, SELF.value := LEFT.w;SELF:=LEFT;));
      mBeta := Types.ToMatrix(Beta0);
      mX_0 := Types.ToMatrix(Indep);
      mXloc := Mat.InsertColumn(mX_0, 1, 1.0); 

      AdjY := $.Mat.Mul(mXloc, $.Mat.Trans(mBeta)) ;
      
      sigmoid := Mat.Each.Each_Reciprocal(Mat.Each.Each_Add(Mat.Each.Each_Exp(Mat.Scale(AdjY, -1)),1));
      
      Types.NumericField tr(sigmoid le) := TRANSFORM
        SELF.value := le.value;
        SELF.id := le.x;
        SELF.number := le.y;
      END;
      RETURN PROJECT(sigmoid,tr(LEFT));
    END;
      
  END; 
  

/*
    Logistic Regression implementation base on the iteratively-reweighted least squares (IRLS) algorithm:
  http:

    Logistic Regression module parameters:
    - Ridge: an optional ridge term used to ensure existance of Inv(X'*X) even if
        some independent variables X are linearly dependent. In other words the Ridge parameter
        ensures that the matrix X'*X+mRidge is non-singular.
    - Epsilon: an optional parameter used to test convergence
    - MaxIter: an optional parameter that defines a maximum number of iterations
    - prows: an optional parameter used to set the number of rows in partition blocks (Should be used in conjuction with pcols)
    - pcols: an optional parameter used to set the number of cols in partition blocks (Should be used in conjuction with prows)
    - Maxrows: an optional parameter used to set maximum rows allowed per block when using AutoBVMap
    - Maxcols: an optional parameter used to set maximum cols allowed per block when using AutoBVMap

    The inputs to the Logis module are:
  a) A training dataset X of discretized independant variables
  b) A dataset of class results Y.

*/
  EXPORT Logistic(REAL8 Ridge=0.00001, REAL8 Epsilon=0.000000001, UNSIGNED2 MaxIter=200, 
    UNSIGNED4 prows=0, UNSIGNED4 pcols=0,UNSIGNED4 Maxrows=0, UNSIGNED4 Maxcols=0) := MODULE(Logistic_Model)

    Logis(DATASET(Types.NumericField) X, DATASET(Types.NumericField) Y) := MODULE
      SHARED mu_comp := ENUM ( Beta = 1,  Y = 2, BetaError = 3, BetaMaxError = 4, VC = 5 );
      SHARED RebaseY := Utils.RebaseNumericField(Y);
      SHARED Y_Map := RebaseY.Mapping(1);
      Y_0 := RebaseY.ToNew(Y_Map);
      SHARED mY := Types.ToMatrix(Y_0);
      mX_0 := Types.ToMatrix(X);
      SHARED mX := IF(NOT EXISTS(mX_0), 
                    Mat.Vec.ToCol(Mat.Vec.From(Mat.Has(mY).Stats.xmax, 1.0), 1), 
                    Mat.InsertColumn(mX_0, 1, 1.0)); 
      mXstats := Mat.Has(mX).Stats;
      mX_n := mXstats.XMax;
      mX_m := mXstats.YMax;

      
      havemaxrow := maxrows > 0;
      havemaxcol := maxcols > 0;
      havemaxrowcol := havemaxrow and havemaxcol;

      derivemap := IF(havemaxrowcol, PBblas.AutoBVMap(mX_n, mX_m,prows,pcols,maxrows, maxcols),
        IF(havemaxrow, PBblas.AutoBVMap(mX_n, mX_m,prows,pcols,maxrows),
        IF(havemaxcol, PBblas.AutoBVMap(mX_n, mX_m,prows,pcols,,maxcols),
        PBblas.AutoBVMap(mX_n, mX_m,prows,pcols))));

      sizeRec := RECORD
        PBblas.Types.dimension_t m_rows;
        PBblas.Types.dimension_t m_cols;
        PBblas.Types.dimension_t f_b_rows;
        PBblas.Types.dimension_t f_b_cols;
      END;

      SHARED sizeTable := DATASET([{derivemap.matrix_rows,derivemap.matrix_cols,derivemap.part_rows(1),derivemap.part_cols(1)}], sizeRec);


      mXmap := PBblas.Matrix_Map(sizeTable[1].m_rows,sizeTable[1].m_cols,sizeTable[1].f_b_rows,sizeTable[1].f_b_cols);
      
      mXdist := DMAT.Converted.FromElement(mX,mXmap);


      
      mYmap := PBblas.Matrix_Map(sizeTable[1].m_rows, 1, sizeTable[1].f_b_rows, 1);
      mYdist := DMAT.Converted.FromElement(mY, mYmap);

      
      Layout_Cell gen(UNSIGNED4 c, UNSIGNED4 NumRows, REAL8 v) := TRANSFORM
      SELF.x := ((c-1) % NumRows) + 1;
      SELF.y := ((c-1) DIV NumRows) + 1;
      SELF.v := v;
      END;

      
      mW := DATASET(sizeTable[1].m_rows, gen(COUNTER, sizeTable[1].m_rows, 1.0),DISTRIBUTED);
      mWdist := DMAT.Converted.FromCells(mYmap, mW);

      
      mRidge := DATASET(sizeTable[1].m_cols, gen(COUNTER, sizeTable[1].m_cols, ridge),DISTRIBUTED);
      RidgeVecMap := PBblas.Matrix_Map(sizeTable[1].m_cols, 1, sizeTable[1].f_b_cols, 1);
      Ridgemap := PBblas.Matrix_Map(sizeTable[1].m_cols, sizeTable[1].m_cols, sizeTable[1].f_b_cols, sizeTable[1].f_b_cols);
      mRidgeVec := DMAT.Converted.FromCells(RidgeVecMap, mRidge);
      mRidgedist := PBblas.Vector2Diag(RidgeVecMap, mRidgeVec, Ridgemap);

      
      mBeta0 := DATASET(sizeTable[1].m_cols, gen(COUNTER, sizeTable[1].m_cols, 0.0),DISTRIBUTED);
      mBeta0map := PBblas.Matrix_Map(sizeTable[1].m_cols, 1, sizeTable[1].f_b_cols, 1);
      mBeta00 := PBblas.MU.To(DMAT.Converted.FromCells(mBeta0map,mBeta0), mu_comp.Beta);

      
      OldExpY_0 := DATASET(sizeTable[1].m_rows, gen(COUNTER, sizeTable[1].m_rows, -1),DISTRIBUTED); 
      OldExpY_00 := PBblas.MU.To(DMAT.Converted.FromCells(mYmap,OldExpY_0), mu_comp.Y);



      
      PBblas.Types.value_t e(PBblas.Types.value_t v, 
            PBblas.Types.dimension_t r, 
            PBblas.Types.dimension_t c) := exp(v);

      PBblas.Types.value_t AddOne(PBblas.Types.value_t v, 
            PBblas.Types.dimension_t r, 
            PBblas.Types.dimension_t c) := 1+v;

      PBblas.Types.value_t Reciprocal(PBblas.Types.value_t v, 
            PBblas.Types.dimension_t r, 
            PBblas.Types.dimension_t c) := 1/v;

      
      PBblas.Types.value_t absv(PBblas.Types.value_t v, 
            PBblas.Types.dimension_t r, 
            PBblas.Types.dimension_t c) := abs(v);
            
      
      weightsMap := PBblas.Matrix_Map(sizeTable[1].m_rows, sizeTable[1].m_rows, sizeTable[1].f_b_rows, sizeTable[1].f_b_rows);
      xWeightMap := PBblas.Matrix_Map(sizeTable[1].m_cols, sizeTable[1].m_rows, sizeTable[1].f_b_cols, sizeTable[1].f_b_rows);
      xtranswadjyMap := PBblas.Matrix_Map(sizeTable[1].m_cols, 1, sizeTable[1].f_b_cols, 1);

        
      Step(DATASET(PBblas.Types.MUElement) BetaPlusY, INTEGER coun) := FUNCTION

        OldExpY := PBblas.MU.From(BetaPlusY, mu_comp.Y);

        BetaDist := PBblas.MU.From(BetaPlusY, mu_comp.Beta);


        AdjY := PBblas.PB_dgemm(FALSE, FALSE, 1.0, mXmap, mXdist, mBeta0map, BetaDist,  mYmap);

        
        negAdjY := PBblas.PB_dscal(-1, AdjY);
        
        e2negAdjY := PBblas.Apply2Elements(mYmap, negAdjY, e);
        
        OnePlusE2negAdjY := PBblas.Apply2Elements(mYmap, e2negAdjY, AddOne);

        
        ExpY := PBblas.Apply2Elements(mYmap, OnePlusE2negAdjY, Reciprocal); 

        
        
        Deriv := PBblas.HadamardProduct(mYmap, Expy, PBblas.Apply2Elements(mYmap,PBblas.PB_dscal(-1, Expy), AddOne));

        
        
        derivXadjy := PBblas.HadamardProduct(mYmap, Deriv, AdjY);
        
        yMINUSexpy := PBblas.PB_daxpy(1.0,mYdist,PBblas.PB_dscal(-1, Expy));
        
        forWadjy := PBblas.PB_daxpy(1, derivXadjy, yMINUSexpy);

        
        w_Adjy := PBblas.HadamardProduct(mYmap, mWdist, forWadjy);

        
        
        derivXw := PBblas.HadamardProduct(mYmap,deriv, mWdist);

        


        Weights := PBblas.Vector2Diag(weightsMap,derivXw,weightsMap);

        
        

        xweight := PBblas.PB_dgemm(TRUE, FALSE, 1.0, mXmap, mXdist, weightsMap, weights, xWeightMap);
        xweightsx :=  PBblas.PB_dgemm(FALSE, FALSE, 1.0, xWeightMap, xweight, mXmap, mXdist, Ridgemap, mRidgedist, 1.0);

        

        side := PBblas.PB_dgemm(TRUE, FALSE,1.0, mXmap, mXdist, mYmap, w_Adjy,xtranswadjyMap);

        LU_xwx  := PBblas.PB_dgetrf(Ridgemap, xweightsx);

        lc  := PBblas.PB_dtrsm(PBblas.Types.Side.Ax, PBblas.Types.Triangle.Lower, FALSE,
           PBblas.Types.Diagonal.UnitTri, 1.0, Ridgemap, LU_xwx, xtranswadjyMap, side);

        mBeta := PBblas.PB_dtrsm(PBblas.Types.Side.Ax, PBblas.Types.Triangle.Upper, FALSE,
             PBblas.Types.Diagonal.NotUnitTri, 1.0, Ridgemap, LU_xwx, xtranswadjyMap, lc);

        
        err := SUM(DMAT.Converted.FromPart2Cell(PBblas.Apply2Elements(mBeta0map,PBblas.PB_daxpy(1.0, mBeta,PBblas.PB_dscal(-1, BetaDist)), absv)), v);

        errmap := PBblas.Matrix_Map(1, 1, 1, 1);

        BE := DATASET([{1,1,err}],Mat.Types.Element);
        BetaError := DMAT.Converted.FromElement(BE,errmap);

        BME := DATASET([{1,1,sizeTable[1].m_cols*Epsilon}],Mat.Types.Element);
        BetaMaxError := DMAT.Converted.FromElement(BME,errmap);         

        RETURN PBblas.MU.To(mBeta, mu_comp.Beta)
                  +PBblas.MU.To(ExpY, mu_comp.Y)
                  +PBblas.MU.To(BetaError,mu_comp.BetaError)
                  +PBblas.MU.To(BetaMaxError,mu_comp.BetaMaxError)
                  +PBblas.MU.To(xweightsx, mu_comp.VC);

      END;
      
      errmap := PBblas.Matrix_Map(1, 1, 1, 1);
      BE := DATASET([{1,1,sizeTable[1].m_cols*Epsilon+1}],Mat.Types.Element);
      BetaError00 := PBblas.MU.To(DMAT.Converted.FromElement(BE,errmap), mu_comp.BetaError);
      
      BME := DATASET([{1,1,sizeTable[1].m_cols*Epsilon}],Mat.Types.Element);
      BetaMaxError00 := PBblas.MU.To(DMAT.Converted.FromElement(BME,errmap), mu_comp.BetaMaxError); 
      SHARED BetaPair := LOOP(mBeta00+OldExpY_00+BetaError00+BetaMaxError00
            , (COUNTER<=MaxIter)
              AND (DMAT.Converted.FromPart2Elm(PBblas.MU.From(ROWS(LEFT),mu_comp.BetaError))[1].value > 
              DMAT.Converted.FromPart2Elm(PBblas.MU.From(ROWS(LEFT),mu_comp.BetaMaxError))[1].value)
            , Step(ROWS(LEFT),COUNTER)
            ); 

      SHARED mBeta00map := PBblas.Matrix_Map(sizeTable[1].m_cols, 1, sizeTable[1].f_b_cols, 1);  
      SHARED xwxmap := PBblas.Matrix_Map(sizeTable[1].m_cols, sizeTable[1].m_cols, sizeTable[1].f_b_cols, sizeTable[1].f_b_cols);
    
      EXPORT Beta := FUNCTION
        mubeta := DMAT.Converted.FromPart2DS(DMAT.Trans.Matrix(mBeta00map,PBblas.MU.From(BetaPair, mu_comp.Beta)));
        rebaseBeta := RebaseY.ToOldFromElemToPart(mubeta, Y_Map);
        RETURN rebaseBeta;
      END;
      
      EXPORT SE := FUNCTION
        mVC := DMat.Inv(xwxmap, PBblas.MU.From(BetaPair, mu_comp.VC));

        muSE := Types.FromMatrix(Mat.Trans(Mat.Vec.ToCol(Mat.Vec.FromDiag(
                    DMAT.Converted.FromPart2Elm(mVC)), 1)));
        rebaseSE := RebaseY.ToOldFromElemToPart(muSE, Y_Map);
        RETURN rebaseSE;
      END;

      Res := FUNCTION
        ret0 := PROJECT(Beta,TRANSFORM(Logis_Model,SELF.Id := COUNTER+Base,SELF.number := LEFT.number-1,
                              SELF.class_number := LEFT.id, SELF.w := LEFT.value, SELF.SE := 0.0));
        ret := JOIN(ret0, SE, LEFT.number+1 = RIGHT.number AND LEFT.class_number = RIGHT.id, 
                    TRANSFORM(Logis_Model,
                              SELF.Id := LEFT.Id,SELF.number := LEFT.number, 
                              SELF.class_number := LEFT.class_number, SELF.w := LEFT.w, SELF.se := SQRT(RIGHT.value)));
        RETURN ret;
      END;
      ML.ToField(Res,o);

      EXPORT Mod := o;
      modelY_M := DMAT.Converted.FromPart2Elm(PBblas.MU.From(BetaPair, mu_comp.Y));
      modelY_NF := RebaseY.ToOld(Types.FromMatrix(modelY_M),Y_Map);
      EXPORT modelY := modelY_NF;
    END;

    EXPORT LearnCS(DATASET(Types.NumericField) Indep,DATASET(Types.DiscreteField) Dep) := Logis(Indep,PROJECT(Dep,Types.NumericField)).mod;
    EXPORT LearnC(DATASET(Types.NumericField) Indep,DATASET(Types.DiscreteField) Dep) := LearnCConcat(Indep,Dep,LearnCS);
    EXPORT ClassifyS(DATASET(Types.NumericField) Indep,DATASET(Types.NumericField) mod) := FUNCTION

      mod0 := Model(mod);
      Beta_0 := PROJECT(mod0,TRANSFORM(Types.NumericField,SELF.Number := LEFT.Number+1,SELF.id := LEFT.class_number, SELF.value := LEFT.w;SELF:=LEFT;));
      RebaseBeta := Utils.RebaseNumericFieldID(Beta_0);
      Beta0_Map := RebaseBeta.MappingID(1);
      Beta0 := RebaseBeta.ToNew(Beta0_Map);

      mX_0 := Types.ToMatrix(Indep);
      mXloc := Mat.InsertColumn(mX_0, 1, 1.0); 

      mXlocstats := Mat.Has(mXloc).Stats;
      mXloc_n := mXlocstats.XMax;
      mXloc_m := mXlocstats.YMax;

      havemaxrow := maxrows > 0;
      havemaxcol := maxcols > 0;
      havemaxrowcol := havemaxrow and havemaxcol;

      
      derivemap := IF(havemaxrowcol, PBblas.AutoBVMap(mXloc_n, mXloc_m,prows,pcols,maxrows, maxcols),
        IF(havemaxrow, PBblas.AutoBVMap(mXloc_n, mXloc_m,prows,pcols,maxrows),
        IF(havemaxcol, PBblas.AutoBVMap(mXloc_n, mXloc_m,prows,pcols,,maxcols),
        PBblas.AutoBVMap(mXloc_n, mXloc_m,prows,pcols))));


      sizeRec := RECORD
        PBblas.Types.dimension_t m_rows;
        PBblas.Types.dimension_t m_cols;
        PBblas.Types.dimension_t f_b_rows;
        PBblas.Types.dimension_t f_b_cols;
      END;

      sizeTable := DATASET([{derivemap.matrix_rows,derivemap.matrix_cols,derivemap.part_rows(1),derivemap.part_cols(1)}], sizeRec);

      mXlocmap := PBblas.Matrix_Map(sizeTable[1].m_rows,sizeTable[1].m_cols,sizeTable[1].f_b_rows,sizeTable[1].f_b_cols);

      mXlocdist := DMAT.Converted.FromElement(mXloc,mXlocmap);

      mBeta := Types.ToMatrix(Beta0);
      mBetastats := Mat.Has(mBeta).Stats;
      mBeta_n := mBetastats.XMax;

      mBetamap := PBblas.Matrix_Map(mBeta_n, sizeTable[1].m_cols, 1, sizeTable[1].f_b_cols);
      mBetadist := DMAT.Converted.FromElement(mBeta,mBetamap);

      AdjYmap := PBblas.Matrix_Map(mXlocmap.matrix_rows, mBeta_n, mXlocmap.part_rows(1), 1);
      AdjY := PBblas.PB_dgemm(FALSE, TRUE, 1.0, mXlocmap, mXlocdist, mBetamap, mBetaDist,AdjYmap);

      

      negAdjY := PBblas.PB_dscal(-1, AdjY);

      PBblas.Types.value_t e(PBblas.Types.value_t v, 
            PBblas.Types.dimension_t r, 
            PBblas.Types.dimension_t c) := exp(v);
            
      PBblas.Types.value_t AddOne(PBblas.Types.value_t v, 
            PBblas.Types.dimension_t r, 
            PBblas.Types.dimension_t c) := 1+v;
            
      PBblas.Types.value_t Reciprocal(PBblas.Types.value_t v, 
            PBblas.Types.dimension_t r, 
            PBblas.Types.dimension_t c) := 1/v;

      e2negAdjY := PBblas.Apply2Elements(AdjYmap, negAdjY, e);

      OnePlusE2negAdjY := PBblas.Apply2Elements(AdjYmap, e2negAdjY, AddOne);

      sig := PBblas.Apply2Elements(AdjYmap, OnePlusE2negAdjY, Reciprocal);

      
      sigtran := DMAT.Trans.Matrix(AdjYmap,sig);

      sigds :=DMAT.Converted.FromPart2DS(sigtran);

      sigconvds := RebaseBeta.ToOld(sigds, Beta0_Map);

      tranmap := PBblas.Matrix_Map(((mXloc_m-1)+mBeta_n), mXlocmap.matrix_rows, 1, mXlocmap.part_rows(1));

      preptranback := DMAT.Converted.FromNumericFieldDS(sigconvds, tranmap);

      sigtranback := DMAT.Trans.Matrix(tranmap, preptranback);

      sigmoid := DMAT.Converted.frompart2elm(sigtranback);

      
      Types.NumericField tr(sigmoid le) := TRANSFORM
        SELF.value := le.value;
        SELF.id := le.x;
        SELF.number := le.y;
      END;

      RETURN PROJECT(sigmoid,tr(LEFT));

    END;

  END; 

/*








*/
EXPORT SoftMax(DATASET (MAT.Types.Element) IntTHETA, REAL8 LAMBDA=0.001, REAL8 ALPHA=0.1, UNSIGNED2 MaxIter=100,
  UNSIGNED4 prows=0, UNSIGNED4 pcols=0,UNSIGNED4 Maxrows=0, UNSIGNED4 Maxcols=0) := MODULE(DEFAULT)
  Soft(DATASET(Types.NumericField) X,DATASET(Types.NumericField) Y) := MODULE
  
  
  
  
  
  dt := Types.ToMatrix (X);
  SHARED dTmp := Mat.InsertColumn(dt,1,1.0); 
  SHARED d := Mat.Trans(dTmp); 
  SHARED groundTruth:= Utils.ToGroundTruth (Y);
  
  SHARED NumClass := Mat.Has(groundTruth).Stats.XMax;
  SHARED sizeRec := RECORD
    PBblas.Types.dimension_t m_rows;
    PBblas.Types.dimension_t m_cols;
    PBblas.Types.dimension_t f_b_rows;
    PBblas.Types.dimension_t f_b_cols;
  END;
   
    SHARED havemaxrow := maxrows > 0;
    SHARED havemaxcol := maxcols > 0;
    SHARED havemaxrowcol := havemaxrow and havemaxcol;
    SHARED dstats := Mat.Has(d).Stats;
    SHARED d_n := dstats.XMax;
    SHARED d_m := dstats.YMax;
    derivemap := IF(havemaxrowcol, PBblas.AutoBVMap(d_n, d_m,prows,pcols,maxrows, maxcols),
                   IF(havemaxrow, PBblas.AutoBVMap(d_n, d_m,prows,pcols,maxrows),
                      IF(havemaxcol, PBblas.AutoBVMap(d_n, d_m,prows,pcols,,maxcols),
                      PBblas.AutoBVMap(d_n, d_m,prows,pcols))));
    SHARED sizeTable := DATASET([{derivemap.matrix_rows,derivemap.matrix_cols,derivemap.part_rows(1),derivemap.part_cols(1)}], sizeRec);
    Ones_VecMap := PBblas.Matrix_Map(1, NumClass, 1, NumClass);
    
    Layout_Cell gen(UNSIGNED4 c, UNSIGNED4 NumRows) := TRANSFORM
      SELF.y := ((c-1) % NumRows) + 1;
      SELF.x := ((c-1) DIV NumRows) + 1;
      SELF.v := 1;
    END;
    
    Ones_Vec := DATASET(NumClass, gen(COUNTER, NumClass));
    Ones_Vecdist := DMAT.Converted.FromCells(Ones_VecMap, Ones_Vec);
    
    dmap := PBblas.Matrix_Map(sizeTable[1].m_rows,sizeTable[1].m_cols,sizeTable[1].f_b_rows,sizeTable[1].f_b_cols);
    ddist := DMAT.Converted.FromElement(d,dmap);
    
    groundTruthmap := PBblas.Matrix_Map(NumClass, sizeTable[1].m_cols, NumClass, sizeTable[1].f_b_cols);
    groundTruthdist := DMAT.Converted.FromElement(groundTruth, groundTruthmap);
    
    IntTHETAmap := PBblas.Matrix_Map(NumClass, sizeTable[1].m_rows, NumClass, sizeTable[1].f_b_rows);
    IntTHETAdist := DMAT.Converted.FromElement(IntTHETA, IntTHETAmap);
    
    col_col_map := PBblas.Matrix_Map(sizeTable[1].m_cols, sizeTable[1].m_cols, sizeTable[1].f_b_cols, sizeTable[1].f_b_cols);
    THETAmap := PBblas.Matrix_Map(NumClass, sizeTable[1].m_rows, NumClass, sizeTable[1].f_b_rows);
    txmap := groundTruthmap;
    SumColMap := PBblas.Matrix_Map(1, sizeTable[1].m_cols, 1, sizeTable[1].f_b_cols);
    
    PBblas.Types.value_t e(PBblas.Types.value_t v,PBblas.Types.dimension_t r,PBblas.Types.dimension_t c) := exp(v);
    PBblas.Types.value_t reci(PBblas.Types.value_t v,PBblas.Types.dimension_t r,PBblas.Types.dimension_t c) := 1/v;
    m := d_m; 
    m_1 := -1 * (1/m);
    Step(DATASET(PBblas.Types.Layout_Part ) THETA) := FUNCTION
      
      tx := PBblas.PB_dgemm(FALSE, FALSE, 1.0, THETAmap, THETA, dmap, ddist, txmap);
      
      tx_mat := DMat.Converted.FromPart2Elm(tx);
      MaxCol_tx_mat := Mat.Has(tx_mat).MaxCol;
      MaxCol_tx := DMAT.Converted.FromElement(MaxCol_tx_mat, SumColMap);
      tx_M := PBblas.PB_dgemm(TRUE, FALSE, -1.0, Ones_VecMap, Ones_Vecdist, SumColMap, MaxCol_tx, txmap, tx, 1.0);
      
        
        
        
      
      
      
      
      exp_tx_M := PBblas.Apply2Elements(txmap, tx_M, e);
      
      SumCol_exp_tx_M := PBblas.PB_dgemm(FALSE, FALSE, 1.0, Ones_VecMap, Ones_Vecdist, txmap, exp_tx_M, SumColMap);
      SumCol_exp_tx_M_rcip := PBblas.Apply2Elements(SumColMap, SumCol_exp_tx_M, Reci);
      SumCol_exp_tx_M_rcip_diag := PBblas.Vector2Diag(SumColMap, SumCol_exp_tx_M_rcip, col_col_map);
      Prob := PBblas.PB_dgemm(FALSE, FALSE, 1.0, txmap, exp_tx_M, col_col_map, SumCol_exp_tx_M_rcip_diag, txmap);
      second_term := PBblas.PB_dscal((1-ALPHA*LAMBDA), THETA);
      groundTruth_Prob := PBblas.PB_daxpy(1.0,groundTruthdist,PBblas.PB_dscal(-1, Prob));
      groundTruth_Prob_x := PBblas.PB_dgemm(FALSE, True, 1.0, txmap, groundTruth_Prob, dmap, ddist, THETAmap);
      
      
      UpdatedTHETA := PBblas.PB_daxpy((-1*ALPHA*m_1), groundTruth_Prob_x, second_term);
      RETURN UpdatedTHETA;
    END; 
    param := LOOP(IntTHETAdist, COUNTER <= MaxIter, Step(ROWS(LEFT)));
    
    EXPORT Mod := ML.DMat.Converted.FromPart2DS (param);
  END; 
  EXPORT LearnC(DATASET(Types.NumericField) Indep, DATASET(Types.DiscreteField) Dep) := Soft(Indep,PROJECT(Dep,Types.NumericField)).mod;
  EXPORT Model(DATASET(Types.NumericField) mod) := FUNCTION
    o:= Types.ToMatrix (Mod);
    RETURN o;
  END; 
  EXPORT ClassProbDistribC(DATASET(Types.NumericField) Indep,DATASET(Types.NumericField) mod) :=FUNCTION
    
    X := Indep;
    dt := Types.ToMatrix (X);
    dTmp := Mat.InsertColumn(dt,1,1.0);
    d := Mat.Trans(dTmp);
    sizeRec := RECORD
      PBblas.Types.dimension_t m_rows;
      PBblas.Types.dimension_t m_cols;
      PBblas.Types.dimension_t f_b_rows;
      PBblas.Types.dimension_t f_b_cols;
    END;
   
    havemaxrow := maxrows > 0;
    havemaxcol := maxcols > 0;
    havemaxrowcol := havemaxrow and havemaxcol;
    dstats := Mat.Has(d).Stats;
    d_n := dstats.XMax;
    d_m := dstats.YMax;
    derivemap := IF(havemaxrowcol, PBblas.AutoBVMap(d_n, d_m,prows,pcols,maxrows, maxcols),
                   IF(havemaxrow, PBblas.AutoBVMap(d_n, d_m,prows,pcols,maxrows),
                      IF(havemaxcol, PBblas.AutoBVMap(d_n, d_m,prows,pcols,,maxcols),
                      PBblas.AutoBVMap(d_n, d_m,prows,pcols))));
    sizeTable := DATASET([{derivemap.matrix_rows,derivemap.matrix_cols,derivemap.part_rows(1),derivemap.part_cols(1)}], sizeRec);
    dmap := PBblas.Matrix_Map(sizeTable[1].m_rows,sizeTable[1].m_cols,sizeTable[1].f_b_rows,sizeTable[1].f_b_cols);
    
    ddist := DMAT.Converted.FromElement(d,dmap);
    param := Model (mod);
    NumClass := Mat.Has(param).Stats.XMax;
    Ones_VecMap := PBblas.Matrix_Map(1, NumClass, 1, NumClass);
    
    Layout_Cell gen(UNSIGNED4 c, UNSIGNED4 NumRows) := TRANSFORM
      SELF.y := ((c-1) % NumRows) + 1;
      SELF.x := ((c-1) DIV NumRows) + 1;
      SELF.v := 1;
    END;
    
    Ones_Vec := DATASET(NumClass, gen(COUNTER, NumClass),DISTRIBUTED);
    Ones_Vecdist := DMAT.Converted.FromCells(Ones_VecMap, Ones_Vec);
    THETAmap := PBblas.Matrix_Map(NumClass, sizeTable[1].m_rows, NumClass, sizeTable[1].f_b_rows);
    THETA := DMAT.Converted.FromElement(param, THETAmap);
    txmap := PBblas.Matrix_Map(NumClass, sizeTable[1].m_cols, NumClass, sizeTable[1].f_b_cols);
    SumColMap := PBblas.Matrix_Map(1, sizeTable[1].m_cols, 1, sizeTable[1].f_b_cols);
    col_col_map := PBblas.Matrix_Map(sizeTable[1].m_cols, sizeTable[1].m_cols, sizeTable[1].f_b_cols, sizeTable[1].f_b_cols);
    PBblas.Types.value_t reci(PBblas.Types.value_t v,PBblas.Types.dimension_t r,PBblas.Types.dimension_t c) := 1/v;
    tx := PBblas.PB_dgemm(FALSE, FALSE, 1.0, THETAmap, THETA, dmap, ddist, txmap);
    
    tx_mat := DMat.Converted.FromPart2Elm(tx);
    MaxCol_tx_mat := Mat.Has(tx_mat).MaxCol;
    MaxCol_tx := DMAT.Converted.FromElement(MaxCol_tx_mat, SumColMap);
    tx_M := PBblas.PB_dgemm(TRUE, FALSE, -1.0, Ones_VecMap, Ones_Vecdist, SumColMap, MaxCol_tx, txmap, tx, 1.0);
    
    PBblas.Types.value_t e(PBblas.Types.value_t v,PBblas.Types.dimension_t r,PBblas.Types.dimension_t c) := exp(v);
    
    exp_tx_M := PBblas.Apply2Elements(txmap, tx_M, e);
    SumCol_exp_tx_M := PBblas.PB_dgemm(FALSE, FALSE, 1.0, Ones_VecMap, Ones_Vecdist, txmap, exp_tx_M, SumColMap);
    SumCol_exp_tx_M_rcip := PBblas.Apply2Elements(SumColMap, SumCol_exp_tx_M, Reci);
    SumCol_exp_tx_M_rcip_diag := PBblas.Vector2Diag(SumColMap, SumCol_exp_tx_M_rcip, col_col_map);
    Prob := PBblas.PB_dgemm(FALSE, FALSE, 1.0, txmap, exp_tx_M, col_col_map, SumCol_exp_tx_M_rcip_diag, txmap);
    Prob_mat := DMAT.Converted.FromPart2Elm (Prob);
    Types.l_result tr(Mat.Types.Element le) := TRANSFORM
      SELF.value := le.x;
      SELF.id := le.y;
      SELF.number := 1; 
      SELF.conf := le.value;
    END;
    RETURN PROJECT (Prob_mat, tr(LEFT));
  END; 
  EXPORT ClassifyC(DATASET(Types.NumericField) Indep,DATASET(Types.NumericField) mod) := FUNCTION
    Dist := ClassProbDistribC(Indep, mod);
    numrow := MAX (Dist,Dist.value);
    S:= SORT(Dist,id,conf);
    SeqRec := RECORD
    l_result;
    INTEGER8 Sequence := 0;
    END;
    
    SeqRec AddS (S l, INTEGER c) := TRANSFORM
    SELF.Sequence := c%numrow;
    SELF := l;
    END;
    Sseq := PROJECT(S, AddS(LEFT,COUNTER));
    classified := Sseq (Sseq.Sequence=0);
    RETURN PROJECT(classified,l_result);
  END; 
END; 
/* From Wikipedia: 
http:
"... Decision tree learning is a method commonly used in data mining.
The goal is to create a model that predicts the value of a target variable based on several input variables.
... A tree can be "learned" by splitting the source set into subsets based on an attribute value test. 
This process is repeated on each derived subset in a recursive manner called recursive partitioning. 
The recursion is completed when the subset at a node has all the same value of the target variable,
or when splitting no longer adds value to the predictions.
This process of top-down induction of decision trees (TDIDT) [1] is an example of a greedy algorithm,
and it is by far the most common strategy for learning decision trees from data, but it is not the only strategy."
The module can learn using different splitting algorithms, and return a model.
The Decision Tree (model) has the same structure independently of which split algorithm was used.
The model  is used to predict the class from new examples.
*/
  EXPORT DecisionTree := MODULE
/*  
    Decision Tree Learning using Gini Impurity-Based criterion
*/
    EXPORT GiniImpurityBased(INTEGER1 Depth=10, REAL Purity=1.0):= MODULE(DEFAULT)
      EXPORT LearnD(DATASET(Types.DiscreteField) Indep, DATASET(Types.DiscreteField) Dep) := FUNCTION
        nodes := ML.Trees.SplitsGiniImpurBased(Indep, Dep, Depth, Purity);
        RETURN ML.Trees.ToDiscreteTree(nodes);
      END;
      EXPORT ClassProbDistribD(DATASET(Types.DiscreteField) Indep,DATASET(Types.NumericField) mod) :=FUNCTION
        RETURN ML.Trees.ClassProbDistribD(Indep, mod);
      END;
      EXPORT ClassifyD(DATASET(Types.DiscreteField) Indep,DATASET(Types.NumericField) mod) := FUNCTION
        RETURN ML.Trees.ClassifyD(Indep,mod);
      END;
      EXPORT Model(DATASET(Types.NumericField) mod) := FUNCTION
        RETURN ML.Trees.ModelD(mod);
      END;
    END;  
/*
    Decision Tree using C4.5 Algorithm (Quinlan, 1987)
*/
    EXPORT C45(BOOLEAN Pruned= TRUE, INTEGER1 numFolds = 3, REAL z = 0.67449) := MODULE(DEFAULT)
      EXPORT LearnD(DATASET(Types.DiscreteField) Indep, DATASET(Types.DiscreteField) Dep) := FUNCTION
        nodes := IF(Pruned, ML.Trees.SplitsIGR_Pruned(Indep, Dep, numFolds, z), ML.Trees.SplitsInfoGainRatioBased(Indep, Dep));
        RETURN ML.Trees.ToDiscreteTree(nodes);
      END;
      EXPORT ClassProbDistribD(DATASET(Types.DiscreteField) Indep,DATASET(Types.NumericField) mod) :=FUNCTION
        RETURN ML.Trees.ClassProbDistribD(Indep, mod);
      END;
      EXPORT ClassifyD(DATASET(Types.DiscreteField) Indep,DATASET(Types.NumericField) mod) := FUNCTION
        RETURN ML.Trees.ClassifyD(Indep,mod);
      END;
      EXPORT Model(DATASET(Types.NumericField) mod) := FUNCTION
        RETURN ML.Trees.ModelD(mod);
      END;
    END;  

/*  C45 Binary Decision Tree
    It learns from continuous data and builds a Binary Decision Tree based on Info Gain Ratio
    Configuration Input
      minNumObj   minimum number of instances in a leaf node, used in splitting process
      maxLevel    stop learning criteria, either tree's level reachs maxLevel depth or no more split can be done.
*/
    EXPORT C45Binary(Types.t_Count minNumObj=2, Types.t_level maxLevel=32) := MODULE(DEFAULT)
      EXPORT LearnC(DATASET(Types.NumericField) Indep, DATASET(Types.DiscreteField) Dep) := FUNCTION
        nodes := ML.Trees.SplitBinaryCBased(Indep, Dep, minNumObj, maxLevel);
        RETURN ML.Trees.ToNumericTree(nodes);
      END;
      EXPORT ClassifyC(DATASET(Types.NumericField) Indep,DATASET(Types.NumericField) mod) := FUNCTION
        RETURN ML.Trees.ClassifyC(Indep,mod);
      END;
      EXPORT Model(DATASET(Types.NumericField) mod) := FUNCTION
        RETURN ML.Trees.ModelC(mod);
      END;
    END; 
  END; 
  
/* From http:
   "... Random Forests grows many classification trees.
   To classify a new object from an input vector, put the input vector down each of the trees in the forest.
   Each tree gives a classification, and we say the tree "votes" for that class.
   The forest chooses the classification having the most votes (over all the trees in the forest).

   Each tree is grown as follows:
   - If the number of cases in the training set is N, sample N cases at random - but with replacement, from the original data.
     This sample will be the training set for growing the tree.
   - If there are M input variables, a number m<<M is specified such that at each node, m variables are selected at random out of the M
     and the best split on these m is used to split the node. The value of m is held constant during the forest growing.
   - Each tree is grown to the largest extent possible. There is no pruning. ..."

Configuration Input
   treeNum    number of trees to generate
   fsNum      number of features to sample each iteration
   Purity     p <= 1.0
   Depth      max tree level
*/
  EXPORT RandomForest(Types.t_Count treeNum, Types.t_Count fsNum, REAL Purity=1.0, Types.t_level Depth=32, BOOLEAN GiniSplit = TRUE):= MODULE
    EXPORT LearnD(DATASET(Types.DiscreteField) Indep, DATASET(Types.DiscreteField) Dep) := FUNCTION
       noofIndependent := MAX(Indep, number);      
       Indepok := ASSERT(Indep, fsNum<noofIndependent, 'The number of features to consider when looking for the best split cannot be greater than total number of features', FAIL);
      nodes := IF(GiniSplit, ML.Ensemble.SplitFeatureSampleGI(Indepok, Dep, treeNum, fsNum, Purity, Depth), 
                             ML.Ensemble.SplitFeatureSampleIGR(Indepok, Dep, treeNum, fsNum, Depth));
      RETURN ML.Ensemble.ToDiscreteForest(nodes);
    END;
    EXPORT LearnC(DATASET(Types.NumericField) Indep, DATASET(Types.DiscreteField) Dep) := FUNCTION
      noofIndependent := MAX(Indep, number); 
      Indepok := ASSERT(Indep, fsNum<noofIndependent, 'The number of features to consider when looking for the best split cannot be greater than total number of features', FAIL);
      nodes := ML.Ensemble.SplitFeatureSampleGIBin(Indepok, Dep, treeNum, fsNum, Purity, Depth);
      RETURN ML.Ensemble.ToContinuosForest(nodes);
    END;
    
    EXPORT Model(DATASET(Types.NumericField) mod) := FUNCTION
      RETURN ML.Ensemble.FromDiscreteForest(mod);
    END;
    
    EXPORT ModelC(DATASET(Types.NumericField) mod) := FUNCTION
      RETURN ML.Ensemble.FromContinuosForest(mod);
    END;
    
    
    EXPORT ClassProbDistribD(DATASET(Types.DiscreteField) Indep, DATASET(Types.NumericField) mod) :=FUNCTION
      RETURN ML.Ensemble.ClassProbDistribForestD(Indep, mod);
    END;
    EXPORT ClassProbDistribC(DATASET(Types.NumericField) Indep,DATASET(Types.NumericField) mod) :=FUNCTION
      RETURN ML.Ensemble.ClassProbDistribForestC(Indep, mod);
    END;
    
    EXPORT ClassifyD(DATASET(Types.DiscreteField) Indep,DATASET(Types.NumericField) mod) := FUNCTION
      RETURN ML.Ensemble.ClassifyDForest(Indep, mod);
    END;
    EXPORT ClassifyC(DATASET(Types.NumericField) Indep,DATASET(Types.NumericField) mod) := FUNCTION
      RETURN ML.Ensemble.ClassifyCForest(Indep,mod);
    END;
  END; 

/*
  Area Under the ROC curve - Multiple Classification Results
  
  
  
  
  
  
  
  
*/
  EXPORT AUCcurvePoint:= RECORD
    Types.t_Count       id;
    Types.t_Discrete    posClass;  
    Types.t_FieldNumber classifier;
    Types.t_FieldReal   thresho;
    Types.t_FieldReal   fpr;
    Types.t_FieldReal   tpr;
    Types.t_FieldReal   deltaPos:=0;
    Types.t_FieldReal   deltaNeg:=0;
    Types.t_FieldReal   cumNeg:=0;
    Types.t_FieldReal   AUC:=0;
  END;
  EXPORT AUC_ROC(DATASET(l_result) classProbDist, Types.t_Discrete positiveClass, DATASET(Types.DiscreteField) allDep) := FUNCTION
    cntREC:= RECORD
      Types.t_FieldNumber classifier;  
      Types.t_Discrete  c_actual;      
      Types.t_FieldReal score :=-1;
      Types.t_count     tp_cnt:= 0;
      Types.t_count     fn_cnt:= 0;
      Types.t_count     fp_cnt:= 0;
      Types.t_count     tn_cnt:= 0;
      Types.t_count     totPos:= 0;
      Types.t_count     totNeg:= 0;      
    END;
    compREC:= RECORD(cntREC)
      Types.t_Discrete  c_modeled;
    END;
    classOfInterest := classProbDist(value = positiveClass);
    dCPD  := DISTRIBUTE(classOfInterest, HASH32(id));
    dDep  := DISTRIBUTE(allDep, HASH32(id));
    compared:= JOIN(dCPD, dDep, LEFT.id=RIGHT.id AND LEFT.number=RIGHT.number,
                            TRANSFORM(compREC, SELF.classifier:= RIGHT.number, SELF.c_actual:=RIGHT.value,
                            SELF.c_modeled:= positiveClass, SELF.score:=ROUND(LEFT.conf, 14)), RIGHT OUTER, LOCAL);
    sortComp:= SORT(compared, classifier, score);
    coi_acc:= TABLE(sortComp, {classifier, score, cntPos:= COUNT(GROUP, c_actual = c_modeled),
                                  cntNeg:= COUNT(GROUP, c_actual<>c_modeled)}, classifier, score, LOCAL);
    coi_tot:= TABLE(coi_acc, {classifier, totPos:= SUM(GROUP, cntPos), totNeg:= SUM(GROUP, cntNeg)}, classifier, FEW);
    
    acc_tot:= JOIN(coi_acc, coi_tot, LEFT.classifier = RIGHT.classifier, TRANSFORM(cntREC , SELF.c_actual:= positiveClass, 
                                                 SELF.fn_cnt:= LEFT.cntPos, SELF.tn_cnt:= LEFT.cntNeg,
                                                 SELF.totPos:= RIGHT.totPos, SELF.totNeg:= RIGHT.totNeg, SELF:= LEFT),LOOKUP);
    cntREC accNegPos(cntREC l, cntREC r) := TRANSFORM
      deltaPos:= IF(l.classifier <> r.classifier, 0, l.fn_cnt) + r.fn_cnt;
      deltaNeg:= IF(l.classifier <> r.classifier, 0, l.tn_cnt) + r.tn_cnt;
      SELF.score:= r.score;
      SELF.tp_cnt:=  r.totPos - deltaPos;
      SELF.fn_cnt:=  deltaPos;
      SELF.fp_cnt:=  r.totNeg - deltaNeg;
      SELF.tn_cnt:= deltaNeg;
      SELF:= r;
    END;
    cntNegPos:= ITERATE(acc_tot, accNegPos(LEFT, RIGHT));
    tmp:= PROJECT(coi_tot, TRANSFORM(cntREC, SELF.classifier:= LEFT.classifier, SELF.c_actual:=  positiveClass,
                           SELF.score:= -1, SELF.tp_cnt:= LEFT.totPos, SELF.fn_cnt:= 0, 
                           SELF.fp_cnt:= LEFT.totNeg, SELF.tn_cnt:= 0, SELF:= LEFT ));
    accnew:= SORT(cntNegPos + tmp, classifier, score);
    
    rocPoints:= PROJECT(accnew, TRANSFORM(AUCcurvePoint, SELF.id:=COUNTER, SELF.thresho:=LEFT.score, SELF.posClass:= positiveClass, 
                                SELF.fpr:= LEFT.fp_cnt/LEFT.totNeg, SELF.tpr:= LEFT.tp_cnt/LEFT.totPos, SELF.AUC:=IF(LEFT.totNeg=0,1,0) ,SELF:=LEFT));
    
    AUCcurvePoint rocArea(AUCcurvePoint l, AUCcurvePoint r) := TRANSFORM
      deltaPos  := if(l.classifier <> r.classifier, 0.0, l.tpr - r.tpr);
      deltaNeg  := if(l.classifier <> r.classifier, 0.0, l.fpr - r.fpr);
      SELF.deltaPos := deltaPos;
      SELF.deltaNeg := deltaNeg;
      
      SELF.AUC      := IF(l.classifier <> r.classifier, 0, IF(r.fpr=0 AND l.tpr=0 AND r.tpr=1, 1, l.AUC) + deltaPos * (l.cumNeg + 0.5* deltaNeg));
      SELF.cumNeg   := IF(l.classifier <> r.classifier, 0, l.cumNeg + deltaNeg);
      SELF:= r;
    END;
    RETURN ITERATE(rocPoints, rocArea(LEFT, RIGHT));
  END;  

  
  
  
  
  
  
  
  /*  svm_type : set type of SVM, SVM.Types.SVM_Type enum
              C_SVC    (multi-class classification)
              NU_SVC   (multi-class classification)
              ONE_CLASS SVM
              EPSILON_SVR  (regression)
              NU_SVR   (regression)
      kernel_type : set type of kernel function, SVM.Types.Kernel_Type enum
              LINEAR: u'*v
              POLY:   polynomial,  (gamma*u'*v + coef0)^degree
              RBF:    radial basis function: exp(-gamma*|u-v|^2)
              SIGMOID: tanh(gamma*u'*v + coef0)
              PRECOMPUTED: precomputed kernel (kernel values in training_set_file)
      degree : degree in kernel function for POLY
      gamma  : gamma in kernel function for POLY, RBF, and SIGMOID
      coef0  : coef0 in kernel function for POLY, SIGMOID
      cost   : the parameter C of C-SVC, epsilon-SVR, and nu-SVR
      eps    : the epsilon for stopping
      nu     : the parameter nu of nu-SVC, one-class SVM, and nu-SVR
      p      : the epsilon in loss function of epsilon-SVR
      shrinking : whether to use the shrinking heuristics, default TRUE
  */
  
  EXPORT SVM(SVM.Types.SVM_Type svm_type, SVM.Types.Kernel_Type kernel_type,
             INTEGER4 degree, REAL8 gamma, REAL8 coef0, REAL8 cost, REAL8 eps,
             REAL8 nu, REAL8 p, BOOLEAN shrinking) := MODULE(DEFAULT)
    SVM.Types.Training_Parameters
    makeParm(UNSIGNED4 dep_field, SVM.Types.SVM_Type svm_type,
             SVM.Types.Kernel_Type kernel_type,
             INTEGER4 degree, REAL8 gamma, REAL8 coef0, REAL8 cost,
             REAL8 eps, REAL8 nu, REAL8 p, BOOLEAN shrinking) := TRANSFORM
      SELF.id := dep_field;
      SELF.svmType := svm_type;
      SELF.kernelType := kernel_type;
      SELF.degree := degree;
      SELF.gamma := gamma;
      SELF.coef0 := coef0;
      SELF.C := cost;
      SELF.eps := eps;
      SELF.nu := nu;
      SELF.p := p;
      SELF.shrinking := shrinking;
      SELF.prob_est := FALSE;
      SELF := [];
    END;
    SHARED Training_Param(UNSIGNED4 df) := ROW(makeParm(df, svm_type,
                                          kernel_type, degree,
                                          gamma, coef0, cost, eps, nu,
                                          p, shrinking));
    
    EXPORT LearnC(DATASET(Types.NumericField) Indep,
                  DATASET(Types.DiscreteField) Dep) := FUNCTION
      depc := PROJECT(Dep, Types.NumericField);
      inst_data := SVM.Converted.ToInstance(Indep, Depc);
      dep_field := dep[1].number;
      tp := DATASET(Training_Param(dep_field));
      mdl := SVM.train(tp, inst_data);
      nf_mdl := SVM.Converted.FromModel(Base, mdl);
      RETURN nf_mdl; 
    END;
    
    
    EXPORT ClassifyC(DATASET(Types.NumericField) Indep,
                     DATASET(Types.NumericField) mod) := FUNCTION
      inst_data := SVM.Converted.ToInstance(Indep);
      mdl := SVM.Converted.ToModel(mod);
      pred := SVM.predict(mdl, inst_data).Prediction;
      
      l_result cvt(SVM.Types.SVM_Prediction p) := TRANSFORM
        SELF.id := p.rid;
        SELF.number := p.id; 
        SELF.value := p.predict_y;
        SELF.conf := 0.5; 
      END;
      rslt := PROJECT(pred, cvt(LEFT));
      RETURN rslt;
    END;
    
  END; 
END;