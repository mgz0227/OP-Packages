#ifndef APP_FILTER_H
#define APP_FILTER_H

#define AF_VERSION "5.3"
#define AF_FEATURE_CONFIG_FILE "/tmp/feature.cfg"

#define MAX_DPI_PKT_NUM 64
#define MIN_HTTP_DATA_LEN 16
#define MAX_APP_NAME_LEN 64
#define MAX_FEATURE_NUM_PER_APP 16 
#define MIN_FEATURE_STR_LEN 8
#define MAX_FEATURE_STR_LEN 128
#define MAX_HOST_URL_LEN 128
#define MAX_REQUEST_URL_LEN 128
#define MAX_FEATURE_BITS 16
#define MAX_POS_INFO_PER_FEATURE 16
#define MAX_FEATURE_LINE_LEN 600
#define MIN_FEATURE_LINE_LEN 16
#define MAX_URL_MATCH_LEN 64
#define MAX_BYPASS_DPI_PKT_LEN 600

//#define CONFIG_KERNEL_FUNC_TEST 1

#define HTTP_GET_METHOD_STR "GET"
#define HTTP_POST_METHOD_STR "POST"
#define HTTP_HEADER "HTTP"
#define NIPQUAD(addr) \
	((unsigned char *)&addr)[0], \
	((unsigned char *)&addr)[1], \
	((unsigned char *)&addr)[2], \
	((unsigned char *)&addr)[3]
#define NIPQUAD_FMT "%u.%u.%u.%u"
#define MAC_ARRAY(a) (a)[0], (a)[1], (a)[2], (a)[3], (a)[4], (a)[5]
#define MAC_FMT "%02x:%02x:%02x:%02x:%02x:%02x"

#define AF_TRUE 1
#define AF_FALSE 0

#define AF_APP_TYPE(a) (a) / 1000
#define AF_APP_ID(a) (a) % 1000
#define MAC_ADDR_LEN      		6

#define HTTPS_URL_OFFSET		9
#define HTTPS_LEN_OFFSET		7

#define MAX_SEARCH_STR_LEN 32

enum AF_FEATURE_PARAM_INDEX{
	AF_PROTO_PARAM_INDEX,
	AF_SRC_PORT_PARAM_INDEX,
	AF_DST_PORT_PARAM_INDEX,
	AF_HOST_URL_PARAM_INDEX,
	AF_REQUEST_URL_PARAM_INDEX,
	AF_DICT_PARAM_INDEX,
	AF_STR_PARAM_INDEX,
	AF_IGNORE_PARAM_INDEX,
};


#define OAF_NETLINK_ID 29
#define MAX_OAF_NL_MSG_LEN 1024

enum E_MSG_TYPE{
	AF_MSG_INIT,
	AF_MSG_ADD_FEATURE,
	AF_MSG_CLEAN_FEATURE,
	AF_MSG_MAX
};
enum AF_WORK_MODE {
	AF_MODE_GATEWAY,
	AF_MODE_BYPASS,
	AF_MODE_BRIDGE,
};
#define MAX_AF_MSG_DATA_LEN 800
typedef struct af_msg{
	int action;
}af_msg_t;

struct af_msg_hdr{
    int magic;
    int len;
};

enum e_http_method{
	HTTP_METHOD_GET = 1,
	HTTP_METHOD_POST,
};
typedef struct http_proto{
	int match;
	int method;
	char *url_pos;
	int url_len;
	char *host_pos;
	int host_len;
	char *data_pos;
	int data_len;
}http_proto_t;

typedef struct https_proto{
	int match;
	char *url_pos;
	int url_len;
}https_proto_t;




typedef struct af_pos_info{
	int pos;
	unsigned char value;
}af_pos_info_t;

#define MAX_PORT_RANGE_NUM 5

typedef struct range_value
{
	int not ;
	int start;
	int end;
} range_value_t;

typedef struct port_info
{
	u_int8_t mode; // 0: match, 1: not match
	int num;
	range_value_t range_list[MAX_PORT_RANGE_NUM];
} port_info_t;

typedef struct af_feature_node{
	struct list_head  		head;
	u_int32_t app_id;
	char app_name[MAX_APP_NAME_LEN];
	char feature[MAX_FEATURE_STR_LEN];
	u_int32_t proto;
	u_int32_t sport;
	u_int32_t dport;
	port_info_t dport_info;
	char host_url[MAX_HOST_URL_LEN];
	char request_url[MAX_REQUEST_URL_LEN];
	int pos_num;
	char search_str[MAX_SEARCH_STR_LEN];
	int ignore;
	af_pos_info_t pos_info[MAX_POS_INFO_PER_FEATURE];
}af_feature_node_t;

typedef struct af_mac_info {
    struct list_head   hlist;
    unsigned char      mac[MAC_ADDR_LEN];
}af_mac_info_t;

typedef struct flow_info{
	struct nf_conn *ct;
	u_int32_t src; 
	u_int32_t dst;
	struct in6_addr *src6;
	struct in6_addr *dst6;
	int l4_protocol;
	u_int16_t sport;
	u_int16_t dport;
	unsigned char *l4_data;
	int l4_len;
	http_proto_t http;
	https_proto_t https;
	u_int32_t app_id;
	u_int8_t app_name[MAX_APP_NAME_LEN];
	u_int8_t drop;
	u_int8_t dir;
	u_int16_t total_len;
	u_int8_t client_hello;
	af_feature_node_t *feature;
}flow_info_t;

int af_register_dev(void);
void af_unregister_dev(void);
void af_init_app_status(void);
int af_get_app_status(int appid);
int regexp_match(char *reg, char *text);
void af_mac_list_init(void);
void af_mac_list_clear(void);
af_mac_info_t * find_af_mac(unsigned char *mac);
int is_user_match_enable(void);

#endif
