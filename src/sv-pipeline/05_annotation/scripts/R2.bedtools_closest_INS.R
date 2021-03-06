#!R
## Compare CNVs
#!/usr/bin/env Rscript
library("optparse")

option_list = list(
        make_option(c("-i", "--inputbed"), type="character", default=NULL,
              help="input bed from bedtools closest", metavar="character"),
        make_option(c("-o", "--outputbed"), type="character", default=NULL,
              help="name of output bed for each query SVID with closest reference svid and information", metavar="character"),
        make_option(c("-p","--population"), type="character", default=NULL,
              help="file indluding population AF to be added", metavar="character" )
               );


#input_bed = 'bedtools_closest.DEL.bed'
#af_bed = 'CMC_V2.cleaned_filters_qual_recalibrated.AF'
#output_bed = 'bedtools_closest.DEL.selected.bed'
#output_svid = 'bedtools_closest.DEL.selected.svid'

opt_parser = OptionParser(option_list=option_list);
opt = parse_args(opt_parser);

input_bed = opt$inputbed
#af_bed = opt$afinfo
output_bed = opt$outputbed
pop_file = opt$population

modify_gnomad_AF<-function(af){
	af_list = strsplit(as.character(af), ',')[[1]]
	out_af=0
	if(length(af_list)>3){
		for(i in af_list[c(1:2,4:length(af_list))]){
			out_af=out_af+as.double(i)
		}
	}
	else if(length(af_list)==3){
		for(i in af_list[c(1:2)]){
			out_af=out_af+as.double(i)
		}
	}
	else if(length(af_list)==2){
		out_af	= out_af+as.double(af_list[1])
	}
	else if(length(af_list)==1){
		out_af	= af
	}
	return(out_af)
	}
AF_cor_vs_RO<-function(out){
	stat_out=data.frame('RO_cff'=0,'AF_cor'=0,'count_SV'=0, 'total_SV'=0)
	RO_range = seq(0,1, by=.05)
	rec=0
	for(i in RO_range){
		tmp = out[!out[,20]<i,]
		af_cor = cor(tmp[,9],tmp[,21])
		rec=rec+1
		stat_out[rec, 1] = i
		stat_out[rec, 2] = af_cor
		stat_out[rec, 3] = nrow(tmp)
		stat_out[rec, 4] = nrow(out)
	}
	return(stat_out)
	}
AF_cor_vs_bp<-function(out){
	stat_out=data.frame('bp_cff'=0,'AF_cor'=0,'count_SV'=0,'total_SV'=0)
	RO_range = seq(0,1000, by=50)
	rec=0
	for(i in RO_range){
		tmp = out[!out$max_bp_dis>i,]
		af_cor = cor(tmp[,9],tmp[,21])
		rec=rec+1
		stat_out[rec, 1] = i
		stat_out[rec, 2] = af_cor
		stat_out[rec, 3] = nrow(tmp)
		stat_out[rec, 4] = nrow(out)
	}
	return(stat_out)
	}
AF_cor_vs_RO_and_bp<-function(out){
	stat_out=data.frame('RO_cff'=0,'bp_cff'=0,'AF_cor'=0,'count_SV'=0,'total_SV'=0)
	RO_range = seq(0,1, by=.05)
	bp_range = seq(0,1000,by=50)
	rec=0
	for(i in RO_range){
		for(j in bp_range){
			#print(c(i,j))
			rec=rec+1
			tmp = out[!out$RO<i & !out$max_bp_dis>j,]
			af_cor = cor(tmp[,9],tmp[,21])
			stat_out[rec, 1] = i
			stat_out[rec, 2] = j
			stat_out[rec, 3] = af_cor
			stat_out[rec, 4] = nrow(tmp)
			stat_out[rec, 5] = nrow(out)
			}}
	return(stat_out)
	}
add_SV_Size<-function(chs){
  chs[,ncol(chs)+1]=0
  colnames(chs)[ncol(chs)]='size_cate'
  chs[!chs[,3]-chs[,2]<5000,][,ncol(chs)]='>5Kb'
  chs[chs[,3]-chs[,2]<5000 & !chs[,3]-chs[,2]<1000,][,ncol(chs)]='1Kb-5Kb'
  chs[chs[,3]-chs[,2]<1000 & !chs[,3]-chs[,2]<500,][,ncol(chs)]='500bp-1Kb'
  chs[chs[,3]-chs[,2]<500,][,ncol(chs)]='<500bp'
  return(chs)
	}

dat=read.table(input_bed,sep='\t', header=T)
dat[,ncol(dat)+1] =abs(dat[,8]-dat[,2])
colnames(dat)[ncol(dat)]='INS_dis'
dat[,ncol(dat)+1] = dat[,13]/dat[,6]
colnames(dat)[ncol(dat)]='INS_ratio'

svid_stat=data.frame(table(dat[,4]))
out = dat[dat[,4]%in%svid_stat[svid_stat[,2]==1,][,1],]
for(j in sort(unique(svid_stat[,2]))){
	if(j>1){
		#print(j)
		tmp = dat[dat[,4]%in%svid_stat[svid_stat[,2]==j,][,1],]
		tmp = tmp[order(tmp[,21], decreasing=T),]
		tmp = tmp[order(tmp[,4]),]
		out=rbind(out, tmp[j*c(1:(length(unique(tmp[,4])))),])
	}
	}
out=out[order(out[,3]),]
out=out[order(out[,2]),]
out=out[order(out[,1]),]

pop=read.table(pop_file)
pop_colname = paste(pop[,1],'AF',sep='_')
pop_colname[pop_colname=='ALL_AF']='AF'

out2 = out[,c('name','name.1',pop_colname,'INS_dis','INS_ratio')]
colnames(out2)[c(1,2)]=c('query_svid','ref_svid')

out2=out2[out2$INS_dis<100 & out2$INS_ratio<10 & out2$INS_ratio>.1,]
write.table(out2, output_bed, quote=F, sep='\t', col.names=T, row.names=F)


