%% =================================================================
%    Function��Theveninģ�͵� EKF SOC ����
%    Input��SoC_upd - ��ʼʱ�̵Ĺ���ֵ��Ĭ��ֵΪ��ʼʱ�̵���ʵֵ
%           Current - ������������ BBDST����.slx ����
%    Description: SoC estimation process using Extented Kalman Filter
%% =================================================================

function [mean_err_EKF,standard_err_EKF,mean_err_UKF,standard_err_UKF] = EKF_UKF_Thev(SoC_upd_init, Currents)
    % tic;  % �����������ʱ�䣬��ʼ
    
    %% Initialization ------------------------------------------------------------------------------------------------
    SoC_real(1,1) = 1;  % Initial real SoC value
    States_real = [SoC_real(1,1);0];  % ��ʵֵ��ʼ״̬ (SoC_real, Up_real)
    States_upd = [SoC_upd_init;0];  % ����ֵ��ʼ״̬ (SOC_upd, Up_upd)
    SoC_AH(1,1) =SoC_upd_init;  % Initail value of AH
    SoC_upd(1,1) = States_upd(1,1);
    % I_standard = 2.5;  % Initial current
    P_Cov = [1e-8 0;0 1e-6];  % �������
    ts  = 1;  % ����ʱ��
    tr = 0.1;  % ��Сʱ����������ģ����ʵ����
    % N = 3600/ts;  % ��������
    N = 5000;
    Capacity = 1.5;  % �������
    Qs = 4e-9;  % SoC ������������
    Qu = 1e-8;  % Up ������������
    R = 1e-6;  %�۲���������
    I_real = Currents;
    
    %--------------�޼��任--------------------            
    n=1;  %ά��
    alp=0.04;
    beta=2;
    kap=2;                                                    
    % lamda=alp^2*(n+kap)-n;          
    lamda=1.5;    
    %---------------Ȩֵȷ��---------------
    Wm=[lamda/(n+lamda),0.5/(n+lamda)+zeros(1,2*n)];                               
    Wc=Wm;
    Wc(1)=Wc(1)+(1-alp^2+beta); 
    %--------------------------------------
    p=1e-6;                %״̬���Э�����ֵ      
    xc(:,1)=SoC_upd_init;  %xc(),ϵͳԤ����º��״ֵ̬ 
    
    Err_EKF(1,1) = SoC_real(1,1)-States_upd(1,1);  % Error between real values and estimated values
    Err_AH(1,1) = SoC_real(1,1)-SoC_AH(1,1); 
    Err_UKF(1,1) = SoC_real(1,1)-xc(1,1);
    
    % Rp = 0.01513;
    % Cp = 47718.90713;
    % tao = Rp * Cp;
    % I_real=zeros(1,N);  % ʵ�ʵ�����ʼ��
    
    for T=2:N
        %% Simulation of real state---------------------------
        for t=(T-1)*ts/tr-(ts/tr-2) : (T-1)*ts/tr+1
            Rp = 0.02346-0.10537*SoC_real(1,t-1)^1+1.1371*SoC_real(1,t-1)^2-4.55188*SoC_real(1,t-1)^3+8.26827*SoC_real(1,t-1)^4-6.93032*SoC_real(1,t-1)^5 +2.1787*SoC_real(1,t-1)^6;
            Cp = 203.1404+3522.78847*SoC_real(1,t-1)-31392.66753*SoC_real(1,t-1)^2+122406.91269*SoC_real(1,t-1)^3-227590.94382*SoC_real(1,t-1)^4+198281.56406*SoC_real(1,t-1)^5 -65171.90395*SoC_real(1,t-1)^6;
            tao = Rp * Cp;
            
            A2=exp(-tr/tao);
            A=[1 0;0 A2];  % State transformation matrix
            B1 = -tr/(Capacity*3600);
            B2=Rp*(1-exp(-tr/tao));
            B=[B1;B2];  % Input control matrix
            
            States_real(:,t) = A*States_real(:,t-1) + B*I_real(1,t) + [sqrt(Qs)*randn;sqrt(Qu)*randn];  % ʵ�ʹ���ģ���� 0.5s ����һ��
            SoC_real(1,t) = States_real(1,t);
        end
        UOC_real = 3.44003+1.71448*States_real(1,t) -3.51247*States_real(1,t)^2 +5.70868*States_real(1,t)^3 -5.06869*States_real(1,t)^4 +1.86699*States_real(1,t)^5;
        Rint_real = 0.04916 +1.19552*States_real(1,t)-6.25333*States_real(1,t)^2+14.24181*States_real(1,t)^3-13.93388*States_real(1,t)^4+2.553*States_real(1,t)^5+4.16285*States_real(1,t)^6-1.8713*States_real(1,t)^7;
        UL_ob = UOC_real - States_real(2,t) - I_real(:,t) * Rint_real  + sqrt(R)*randn;  % ģ��ʵ�ʵ�ѹ
        ul2 = UOC_real - I_real(:,t) * Rint_real-  I_real(:,t)*Rp*(1-exp(-ts/(Rp*Cp))) + sqrt(R)*randn;
        
        % ģ���������ֵ��ʵ�ʲ��������������󿨶���Ч��Ҳ���ã��������ڰ�ʱ���ֵ�Ч��
        % I_est = I_real(T) + abs((0.05*Capacity)*randn);
        % �������ֵһֱ��ʵ��ֵ������(��)ƫ���ʱ���ִ�������ۼƣ����������˲��յĵ�Ӱ��ԶԶ���ڰ�ʱ����
        % I_est = I_real(T) + abs((0.05*Capacity)*randn);
        I_est = I_real(t) + (0.01*Capacity)*randn;
        SoC_AH(1,T) = SoC_AH(1,T-1) - ts/(Capacity*3600)*I_est;
        %% EKF process ----------------------------------------
        % ------------- Ԥ �� ----------------
        Rp = 0.02346-0.10537*SoC_upd(1,T-1)^1+1.1371*SoC_upd(1,T-1)^2-4.55188*SoC_upd(1,T-1)^3+8.26827*SoC_upd(1,T-1)^4-6.93032*SoC_upd(1,T-1)^5 +2.1787*SoC_upd(1,T-1)^6;
        Cp = 203.1404+3522.78847*SoC_upd(1,T-1)-31392.66753*SoC_upd(1,T-1)^2+122406.91269*SoC_upd(1,T-1)^3-227590.94382*SoC_upd(1,T-1)^4+198281.56406*SoC_upd(1,T-1)^5 -65171.90395*SoC_upd(1,T-1)^6;
        A2=exp(-ts/Rp/Cp);
        A=[1 0;0 A2];  % State transformation matrix
        B1 = -ts/(Capacity*3600);
        B2=Rp*(1-exp(-ts/Rp/Cp));
        B=[B1;B2];  % Input control matrix
        States_pre = A*States_upd(:,T-1) + B*I_est;  % ����һʱ��״̬��Ԥ���ʱ��״̬��������SoC,������ѹֵ
        P_Cov = A*P_Cov*A' + [Qs 0;0 Qu];  % ����
        UOC_pre = 3.44003+1.71448*States_pre(1,1) -3.51247*States_pre(1,1)^2 +5.70868*States_pre(1,1)^3 -5.06869*States_pre(1,1)^4 +1.86699*States_pre(1,1)^5;
        Rint_pre = 0.04916 +1.19552*States_pre(1,1)-6.25333*States_pre(1,1)^2+14.24181*States_pre(1,1)^3-13.93388*States_pre(1,1)^4+2.553*States_pre(1,1)^5+4.16285*States_pre(1,1)^6-1.8713*States_pre(1,1)^7;
        UL_pre = UOC_pre - States_pre(2,1)- I_est * Rint_pre;  % subs(Rint,SoC_upd(1,t-1));  % Ԥ���ѹ
        % -------------- �� �� --------------
        C1 = 1.71448 -2*3.51247*SoC_upd(1,T-1) +3*5.70868*SoC_upd(1,T-1)^2 -4*5.06869*SoC_upd(1,T-1)^3 +5*1.86699*SoC_upd(1,T-1)^4;
        C = [C1 -1];
        K = P_Cov*C'* (C*P_Cov*C'+R)^(-1);  % ����
        States_upd(:,T) = States_pre + K * (UL_ob - UL_pre);  % �õ�����ֵ
        P_Cov = P_Cov - K * C * P_Cov;
        SoC_upd(1,T) = States_upd(1,T);
        
        %% UKF process ---------------------------------------- 
        Xsigma=xc(T-1);
        pk=sqrt((n+lamda)*p);
        %---------------ȷ��sigma������------------
        for k=1:n
           sigma1(k)=Xsigma+pk;
           sigma2(k)=Xsigma-pk;
        end
        sigma=[Xsigma sigma1 sigma2];
        %-------------ϵͳ״̬Ԥ�ⷽ��----------------
        sxk=0;     %״̬����ֵ
        for ks=1:2*n+1
            sigma(ks)=sigma(ks)-I_est*ts/(Capacity*3600);
            sxk=Wm(ks)*sigma(ks)+sxk;         
        end
        spk=0;     %����״̬����Э�������Ԥ��
        for kp=1:2*n+1
            spk=Wc(kp)*(sigma(kp)-sxk)*(sigma(kp)-sxk)'+spk;  % ���Э��������Ԥ��  
        end
        spk=spk+Qs;
        %------һ�θ���sigma������ΪResigma--------
        pkr=sqrt((n+lamda)*spk);  
        for k=1:n
           Resigma1(k)=sxk+pkr;
           Resigma2(k)=sxk-pkr;
        end
        Resigma=[sxk Resigma1 Resigma2];
        %--------------�۲ⷽ��--------------
        for kg=1:2*n+1
            Uoc1 = 3.44003+1.71448*Resigma(kg) -3.51247*Resigma(kg)^2 +5.70868*Resigma(kg)^3 -5.06869*Resigma(kg)^4 +1.86699*Resigma(kg)^5;
            Rint_pre = 0.04916 +1.19552*Resigma(kg)-6.25333*Resigma(kg)^2+14.24181*Resigma(kg)^3-13.93388*Resigma(kg)^4+2.553*Resigma(kg)^5+4.16285*Resigma(kg)^6-1.8713*Resigma(kg)^7;
            Rp = 0.02346-0.10537*Resigma(kg)^1+1.1371*Resigma(kg)^2-4.55188*Resigma(kg)^3+8.26827*Resigma(kg)^4-6.93032*Resigma(kg)^5 +2.1787*Resigma(kg)^6;
            Cp = 203.1404+3522.78847*Resigma(kg)-31392.66753*Resigma(kg)^2+122406.91269*Resigma(kg)^3-227590.94382*Resigma(kg)^4+198281.56406*Resigma(kg)^5 -65171.90395*Resigma(kg)^6;
            gamma(kg)=Uoc1-I_est*Rint_pre-I_est*Rp*(1-exp(-ts/(Rp*Cp)));      %�۲�һ��Ԥ��
        end
        syk=0;     %��������ֵ
        for ky=1:2*n+1
            syk=syk+Wm(ky)*gamma(ky);     %��ֵ
        end
        pyy=0;     %���ڲ���ֵ�������        
        for kpy=1:2*n+1
            pyy=Wc(kpy)*(gamma(kpy)-syk)*(gamma(kpy)-syk)'+pyy;     %���Э����
        end
        pyy=pyy+R;
        %--------------���Э����--------------
        pxy=0;     %���Э�������
        for kxy=1:2*n+1
            pxy=Wc(kxy)*(Resigma(kxy)-sxk)*(gamma(kxy)-syk)'+pxy;  % ����״̬�������������֮��ġ���ϵ��
        end
        %------------����ϵ��������������-------
        %---------------------------------------
        kgs=pxy/pyy; 
        %------------ϵͳ״̬�����Э���������--
        xc(T)=sxk+kgs*(ul2-syk);    %ϵͳ״̬��ͨ���۲�ֵ�����ϵ�����Ԥ��ֵ
        p=spk-kgs*pyy*kgs';          %״̬���Э�������
        
        %% Error -------------------------------------------------
        Err_EKF(1,T) = SoC_real(1,t) - SoC_upd(1,T);  % Error of EKF
        Err_UKF(1,T)=SoC_real(1,t)-xc(T);      %�˲����������
        Err_AH(1,T) = SoC_real(1,t) - SoC_AH(1,T);  % Error of AH
    end 
        
    mean_err_EKF = mean(Err_EKF);  % EKF ���ƽ��ֵ
    standard_err_EKF = std(Err_EKF,0);  % EKF ����׼��
    mean_err_UKF = mean(Err_UKF);  % EKF ���ƽ��ֵ
    standard_err_UKF = std(Err_UKF,0);  % EKF ����׼��
    
    %% Draw Points ------------------------------------------------------------------------------------------------
    %% ������ʾ
    % T = 1:N;
    % figure;
    % subplot(2,1,1);
    % plot(T,SoC_real(1,1:(ts/tr):(N*ts/tr-1)),'LineWidth',2); 
    % hold on;
    % plot(T,SoC_upd(1,1:N),'.g');
    % grid on;
    % xlabel('t(s)');
    % ylabel('SOC');
    % legend('SoC_{Real}','SoC_{SVM-UKF}');
    % subplot(2,1,2);
    % plot(T,Err_EKF(1,1:N),'-g');
    % grid on;
    % xlabel(' t(s)');
    % ylabel('error');
    % legend('Err_{SVM-UKF}','Location','NorthWest');
    
    %% ������ʾ
    T = 1:N;
    figure;
    subplot(2,1,1);
    plot(T,SoC_real(1,1:(ts/tr):(N*ts/tr-1)),'LineWidth',2);
    hold on;
    plot(T,SoC_AH(1,1:N),'-.m',T,SoC_upd(1,1:N),'-.g');
    plot(T,xc(1:N),'-.','Color',[1 0.5 0]);
    grid on;
    xlabel('t(s)');
    ylabel('SOC');
    legend('SoC_{Real}','SoC_{AH}','SoC_{EKF}','SoC_{UKF}');
    subplot(2,1,2);
    plot(T,Err_AH(1,1:N),'-r',T,Err_EKF(1,1:N),'-.g');
    hold on;
    plot(T,Err_UKF(1,1:N),'-.','Color',[1 0.5 0]);
    grid on;
    xlabel(' t(s)');
    ylabel('error');
    legend('Err_{AH}','Err_{EKF}','Err_{UKF}','Location','Best');
    
    %% UKF��Ч��
    % T = 1:N;
    % figure;
    % subplot(2,1,1);
    % plot(T,SoC_real(1,1:(ts/tr):(N*ts/tr-1)),'LineWidth',2);
    % hold on;
    % plot(T,SoC_AH(1,1:N),'-.','Color',[1 0.5 0]);
    % plot(T,xc(1:N),':.','Color',[1 0 1]);
    % grid on;
    % xlabel('t(s)');
    % ylabel('SOC');
    % legend('SoC_{Real}','SoC_{AH}','SoC_{UKF}','Location','Best');
    % subplot(2,1,2);
    % plot(T,Err_AH(1,1:N),'-','Color',[1 0.5 0]);
    % hold on;
    % plot(T,Err_UKF(1,1:N),':.','Color',[1 0 1]);
    % grid on;
    % xlabel(' t(s)');
    % ylabel('error');
    % legend('Err_{AH}','Err_{UKF}','Location','Best');
    
    % toc;  % �����������ʱ�䣬����
    
    